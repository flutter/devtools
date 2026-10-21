// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import '../analytics/analytics.dart' as ga;
import '../development_helpers.dart';
import '../globals.dart';
import '../primitives/query_parameters.dart';
import '../primitives/utils.dart';
import '../server/server.dart' as server;
import '../utils/utils.dart';
import 'notifications.dart';

final _log = Logger('survey');

class SurveyService {
  static const _noThanksLabel = 'No thanks';

  static const _takeSurveyLabel = 'Take survey';

  static const _maxShowSurveyCount = 5;

  /// The URL that we will fetch the DevTools survey metadata from.
  ///
  /// To run new surveys, update the content at
  /// https://github.com/flutter/uxr/blob/master/surveys/devtools-survey-metadata.json.
  ///
  /// This content will be propagated to the storage.googleapis.com domain
  /// automatically.
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
    if (!server.isDevToolsServerAvailable && !debugSurvey) return null;

    _cachedSurvey ??= await fetchSurveyContent();
    if (_cachedSurvey?.id != null) {
      // TODO(kenz): consider setting this value on the [SurveyService] and then
      // we can send the active survey as a parameter in each survey-related
      // DevTools server request. This would simplify the server API for
      // DevTools surveys.
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
          label: _noThanksLabel,
          onPressed: () => _noThanksPressed(message: message),
        ),
        NotificationAction(
          label: _takeSurveyLabel,
          onPressed: () => _takeSurveyPressed(
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
          safeUnawaited(server.incrementSurveyShownCount());
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
        final contents = json.decode(response.body) as Map<String, Object?>;
        return DevToolsSurvey.fromJson(contents);
      }
    } on Error catch (e, st) {
      _log.shout('Error fetching survey content: $e', e, st);
    }
    return null;
  }

  void _noThanksPressed({required String message}) async {
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

  factory DevToolsSurvey.fromJson(Map<String, Object?> json) {
    final id = json[_uniqueIdKey] as String?;
    final startDateAsString = json[_startDateKey] as String?;
    final endDateAsString = json[_endDateKey] as String?;
    final minVersionAsString = json[_minDevToolsVersionKey] as String?;

    final startDate = startDateAsString != null
        ? DateTime.parse(startDateAsString)
        : null;
    final endDate = endDateAsString != null
        ? DateTime.parse(endDateAsString)
        : null;
    final title = json[_titleKey] as String?;
    final surveyUrl = json[_urlKey] as String?;
    final minDevToolsVersion = minVersionAsString != null
        ? SemanticVersion.parse(minVersionAsString)
        : null;
    final devEnvironments = (json[_devEnvironmentsKey] as List?)
        ?.cast<String>()
        .toList();
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
  /// `_ideLaunched` from [shared/analytics/_analytics_web.dart]. They can also
  /// be the labels of the Dash tools that IDEs pass in the `dashTool` query
  /// parameter (e.g. 'vscode-plugins', 'intellij-plugins'), which are shared by
  /// every variant of an IDE (e.g. VS Code, Cursor and Antigravity). Versions
  /// of DevTools that predate the `dashTool` query parameter only recognize the
  /// former.
  final List<String>? devEnvironments;
}

extension ShowSurveyExtension on DevToolsSurvey {
  bool get meetsDateRequirement => (startDate == null || endDate == null)
      ? false
      : Range(
          startDate!.millisecondsSinceEpoch,
          endDate!.millisecondsSinceEpoch,
        ).contains(_currentClockTime().millisecondsSinceEpoch);

  bool get meetsMinVersionRequirement =>
      minDevToolsVersion == null ||
      SemanticVersion.parse(
        devToolsVersion,
      ).isSupported(minSupportedVersion: minDevToolsVersion!);

  /// Whether this survey should be shown in the development environment that
  /// the current DevTools session was launched from.
  ///
  /// See [meetsEnvironmentRequirementFor] for how [devEnvironments] are matched.
  bool get meetsEnvironmentRequirement => meetsEnvironmentRequirementFor(
    ideLaunched: ga.ideLaunched,
    queryParams: DevToolsQueryParams.load(),
  );

  /// Whether this survey should be shown in the development environment that
  /// DevTools was launched from, which is described by [ideLaunched] and
  /// [queryParams].
  ///
  /// A survey that lists [devEnvironments] is shown if it lists the legacy
  /// [ideLaunched] value, or the `dashTool` of the IDE integration that
  /// launched DevTools. The legacy 'VSCode' environment also matches VS Code
  /// forks (such as Cursor or Antigravity), which may not pass 'VSCode' as
  /// their legacy IDE value.
  @visibleForTesting
  bool meetsEnvironmentRequirementFor({
    required String ideLaunched,
    required DevToolsQueryParams queryParams,
  }) {
    final environments = devEnvironments;
    if (environments == null || ideLaunched.isEmpty) return true;

    final dashTool = queryParams.dashTool;
    // When an IDE integration passes `dashTool` without the legacy `ide`
    // parameter, `ga.ideLaunched` defaults to 'CLI'. Ignore that fallback so
    // IDE launches do not match 'CLI' surveys.
    final matchesIdeLaunched =
        (dashTool == null || queryParams.ide != null) &&
        environments.contains(ideLaunched);
    return matchesIdeLaunched ||
        (dashTool != null && environments.contains(dashTool)) ||
        (queryParams.isVsCode &&
            environments.contains(DevToolsQueryParams.legacyVsCodeIdeValue));
  }

  bool get shouldShow =>
      meetsDateRequirement &&
      meetsMinVersionRequirement &&
      meetsEnvironmentRequirement;
}

DateTime _currentClockTime() => fakeClockTimeForSurvey ?? DateTime.now();

/// A hook to set a fake clock time for tests.
@visibleForTesting
DateTime? fakeClockTimeForSurvey;
