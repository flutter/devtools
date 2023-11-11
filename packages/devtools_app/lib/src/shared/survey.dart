// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import '../shared/notifications.dart';
import 'analytics/analytics.dart' as ga;
import 'config_specific/launch_url/launch_url.dart';
import 'development_helpers.dart';
import 'globals.dart';
import 'primitives/utils.dart';
import 'server/server.dart' as server;

final _log = Logger('survey');

class SurveyService {
  static const _noThanksLabel = 'NO THANKS';

  static const _takeSurveyLabel = 'TAKE SURVEY';

  static const _maxShowSurveyCount = 5;

  static final _metadataUrl =
      Uri.https('docs.flutter.dev', '/f/dart-devtools-survey-metadata.json');

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

    _cachedSurvey ??= await _fetchSurveyContent();
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

    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    final activeSurveyRange = Range(
      _cachedSurvey!.startDate!.millisecondsSinceEpoch,
      _cachedSurvey!.endDate!.millisecondsSinceEpoch,
    );
    return activeSurveyRange.contains(currentTimeMs);
  }

  Future<DevToolsSurvey?> _fetchSurveyContent() async {
    try {
      if (debugSurvey) {
        return debugSurveyMetadata;
      }
      final response = await get(_metadataUrl);
      if (response.statusCode == 200) {
        final Map<String, dynamic> contents = json.decode(response.body);
        return DevToolsSurvey.parse(contents);
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
    await launchUrl(surveyUrl);
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
  );

  factory DevToolsSurvey.parse(Map<String, dynamic> json) {
    final id = json['uniqueId'];
    final startDate =
        json['startDate'] != null ? DateTime.parse(json['startDate']) : null;
    final endDate =
        json['startDate'] != null ? DateTime.parse(json['endDate']) : null;
    final title = json['title'];
    final surveyUrl = json['url'];
    return DevToolsSurvey._(id, startDate, endDate, title, surveyUrl);
  }

  final String? id;

  final DateTime? startDate;

  final DateTime? endDate;

  final String? title;

  final String? url;
}
