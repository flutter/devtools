// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import '../../../devtools.dart' as devtools show version;
import '../shared/notifications.dart';
import 'analytics/analytics.dart' as ga;
import 'development_helpers.dart';
import 'globals.dart';
import 'primitives/utils.dart';
import 'server/server.dart' as server;
import 'utils.dart';

final _log = Logger('survey');

class SurveyService {
  static const _noThanksLabel = 'NO THANKS';

  static const _takeSurveyLabel = 'TAKE SURVEY';

  static const _maxShowSurveyCount = 5;

  static final _metadataUrl = Uri.https(
    'storage.googleapis.com',
    'flutter-uxr/surveys/devtools-survey-metadata.json',
  );

  /// Duration for which we should show the survey notification.
  ///
  /// We use a very long time here to give the appearance of a persistent
  /// notification. The user will need to interact with the prompt to dismiss
  /// it.
  static const _notificationDuration = Duration(days: 1);

  DevToolsSurvey? _cachedSurvey;

  Future<DevToolsSurvey?> get activeSurvey async {
    // If the server is unavailable we don't need to do anything survey related.
    if (!server.isDevToolsServerAvailable) return null;

    _cachedSurvey ??= await fetchSurveyContent();
    if (_cachedSurvey?.id != null) {
      await server.setActiveSurvey(_cachedSurvey!.id!);
    }

    if (await _shouldShowSurvey()) {
      return _cachedSurvey;
    }
    return null;
  }

  void maybeShowSurveyPrompt() async {
    final survey = await activeSurvey;
    if (survey != null) {
      final message = survey.title!;
      final actions = [
        NotificationAction(
          _noThanksLabel,
          () => _noThanksPressed(
            message: message,
          ),
        ),
        NotificationAction(
          _takeSurveyLabel,
          () => _takeSurveyPressed(
            surveyUrl: _generateSurveyUrl(survey.url!),
            message: message,
          ),
          isPrimary: true,
        ),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final didPush = notificationService.pushNotification(
          NotificationMessage(
            message,
            actions: actions,
            duration: _notificationDuration,
          ),
          allowDuplicates: false,
        );
        if (didPush) {
          server.incrementSurveyShownCount();
        }
      });
    }
  }

  String _generateSurveyUrl(String surveyUrl) {
    final uri = Uri.parse(surveyUrl);
    final queryParams = ga.generateSurveyQueryParameters();
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      queryParameters: queryParams,
    ).toString();
  }

  Future<bool> _shouldShowSurvey() async {
    if (_cachedSurvey == null) return false;

    final surveyShownCount = await server.surveyShownCount();
    if (surveyShownCount >= _maxShowSurveyCount) return false;

    final surveyActionTaken = await server.surveyActionTaken();
    if (surveyActionTaken) return false;

    return _cachedSurvey!.shouldShow;
  }

  @visibleForTesting
  Future<DevToolsSurvey?> fetchSurveyContent() async {
    try {
      if (debugSurvey) {
        return debugSurveyMetadata;
      }
      final response = await get(_metadataUrl);
      if (response.statusCode == 200) {
        final Map<String, dynamic> contents = json.decode(response.body);
        return DevToolsSurvey.fromJson(contents);
      }
    } on Error catch (e, st) {
      _log.shout('Error fetching survey content: $e', e, st);
    }
    return null;
  }

  void _noThanksPressed({
    required String message,
  }) async {
    await server.setSurveyActionTaken();
    notificationService.dismiss(message);
  }

  void _takeSurveyPressed({
    required String surveyUrl,
    required String message,
  }) async {
    await launchUrlWithErrorHandling(surveyUrl);
    await server.setSurveyActionTaken();
    notificationService.dismiss(message);
  }
}

class DevToolsSurvey {
  DevToolsSurvey._(
    this.id,
    this.startDate,
    this.endDate,
    this.title,
    this.url,
    this.minDevToolsVersion,
    this.devEnvironments,
  );

  factory DevToolsSurvey.fromJson(Map<String, dynamic> json) {
    final id = json[_uniqueIdKey];
    final startDate = json[_startDateKey] != null
        ? DateTime.parse(json[_startDateKey])
        : null;
    final endDate =
        json[_endDateKey] != null ? DateTime.parse(json[_endDateKey]) : null;
    final title = json[_titleKey];
    final surveyUrl = json[_urlKey];
    final minDevToolsVersion = json[_minDevToolsVersionKey] != null
        ? SemanticVersion.parse(json[_minDevToolsVersionKey])
        : null;
    final devEnvironments =
        (json[_devEnvironmentsKey] as List?)?.cast<String>().toList();
    return DevToolsSurvey._(
      id,
      startDate,
      endDate,
      title,
      surveyUrl,
      minDevToolsVersion,
      devEnvironments,
    );
  }

  static const _uniqueIdKey = 'uniqueId';
  static const _startDateKey = 'startDate';
  static const _endDateKey = 'endDate';
  static const _titleKey = 'title';
  static const _urlKey = 'url';
  static const _minDevToolsVersionKey = 'minDevToolsVersion';
  static const _devEnvironmentsKey = 'devEnvironments';

  final String? id;

  final DateTime? startDate;

  final DateTime? endDate;

  final String? title;

  /// The url for the survey that the user will open in a browser when they
  /// respond to the survey prompt.
  final String? url;

  /// The minimum DevTools version that this survey should is for.
  ///
  /// If the current version of DevTools is older than [minDevToolsVersion], the
  /// survey prompt in DevTools will not be shown.
  ///
  /// If [minDevToolsVersion] is null, the survey will be shown for any version
  /// of DevTools as long as all the other requirements are satisfied.
  final SemanticVersion? minDevToolsVersion;

  /// A list of development environments to show the survey for (e.g. 'VSCode',
  /// 'Android-Studio', 'IntelliJ-IDEA', 'CLI', etc.).
  ///
  /// If [devEnvironments] is null, the survey can be shown to any platform.
  ///
  /// The possible values for this list correspond to the possible values of
  /// [_ideLaunched] from [shared/analytics/_analytics_web.dart].
  final List<String>? devEnvironments;
}

extension ShowSurveyExtension on DevToolsSurvey {
  bool get meetsDateRequirement => (startDate == null || endDate == null)
      ? false
      : Range(
          startDate!.millisecondsSinceEpoch,
          endDate!.millisecondsSinceEpoch,
        ).contains(clock.now().millisecondsSinceEpoch);

  bool get meetsMinVersionRequirement =>
      minDevToolsVersion == null ||
      SemanticVersion.parse(devtools.version)
          .isSupported(minSupportedVersion: minDevToolsVersion!);

  bool get meetsEnvironmentRequirement =>
      devEnvironments == null || devEnvironments!.contains(ga.ideLaunched);

  bool get shouldShow =>
      meetsDateRequirement &&
      meetsMinVersionRequirement &&
      meetsEnvironmentRequirement;
}
