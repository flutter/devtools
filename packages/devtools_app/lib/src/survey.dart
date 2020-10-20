import 'dart:convert';

import 'dart:io' if (dart.library.html) 'dart:html';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart';

import 'config_specific/logger/logger.dart';
import 'config_specific/server/server.dart' as server;
import 'notifications.dart';
import 'utils.dart';

class SurveyService {
  static const noThanksLabel = 'NO THANKS';

  static const takeSurveyLabel = 'TAKE SURVEY';

  static const maxShowSurveyCount = 5;

  static const metadataUrl =
      'https://flutter.dev/f/dart-devtools-survey-metadata.json';

  /// Duration for which we should show the survey notification.
  ///
  /// We use a very long time here to give the appearance of a persistent
  /// notification. The user will need to interact with the prompt to dismiss
  /// it.
  static const notificationDuration = Duration(days: 1);

  /// The amount of time (one day) to wait between checks to the file at
  /// [metadataUrl].
  static const checkInterval = Duration(days: 1);

  DevToolsSurvey _cachedSurvey;

  Future<DevToolsSurvey> get activeSurvey async {
    if (await shouldFetchSurveyContent()) {
      _cachedSurvey = await fetchSurveyContent();
      if (_cachedSurvey != null) {
        await server.setActiveSurvey(_cachedSurvey.id);
      }
    }

    if (await shouldShowSurvey()) {
      return _cachedSurvey;
    }
    return null;
  }

  void maybeShowSurveyPrompt(BuildContext context) async {
    final survey = await activeSurvey;
    if (survey != null) {
      final message = survey.title;
      final actions = [
        NotificationAction(
          noThanksLabel,
          () => _noThanksPressed(message, context),
        ),
        NotificationAction(
          takeSurveyLabel,
          () => _takeSurveyPressed(survey.url, context),
          isPrimary: true,
        ),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final didPush = Notifications.of(context).push(
          message,
          actions: actions,
          duration: notificationDuration,
          allowDuplicates: false,
        );
        if (didPush) {
          server.incrementSurveyShownCount();
        }
      });
    }
  }

  Future<bool> shouldShowSurvey() async {
    if (_cachedSurvey == null) return false;

    final surveyShownCount = await server.surveyShownCount();
    if (surveyShownCount >= maxShowSurveyCount) return false;

    final surveyActionTaken = await server.surveyActionTaken();
    if (surveyActionTaken) return false;

    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    final activeSurveyRange = Range(
      _cachedSurvey.startDate.millisecondsSinceEpoch,
      _cachedSurvey.endDate.millisecondsSinceEpoch,
    );
    return activeSurveyRange.contains(currentTimeMs);
  }

  Future<bool> shouldFetchSurveyContent() async {
    // TODO(kenz): consider storing the survey content on DevTools server, or
    // else the content will be re-fetched for each instance of DevTools (e.g.
    // if it was closed and re-opened).
    if (_cachedSurvey == null) return true;

    // Don't check more often than daily.
    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    final lastCheckedTimeMs = await server.getLastSurveyContentCheckMs();

    final shouldFetch = lastCheckedTimeMs == null ||
        currentTimeMs - lastCheckedTimeMs >= checkInterval.inMilliseconds;
    return shouldFetch;
  }

  Future<DevToolsSurvey> fetchSurveyContent() async {
    try {
      final response = await get(metadataUrl);
      if (response.statusCode == HttpStatus.ok) {
        final Map<String, dynamic> contents = json.decode(response.body);
        await server
            .setLastSurveyContentCheckMs(DateTime.now().millisecondsSinceEpoch);
        return DevToolsSurvey.parse(contents);
      }
    } on Error catch (e) {
      log('Error fetching survey content: $e');
    }
    return null;
  }

  void _noThanksPressed(String message, BuildContext context) async {
    await server.setSurveyActionTaken();
    Notifications.of(context).dismiss(message);
  }

  void _takeSurveyPressed(String surveyUrl, BuildContext context) async {
    await server.setSurveyActionTaken();
    await launchUrl(surveyUrl, context);
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

  final String id;

  final DateTime startDate;

  final DateTime endDate;

  final String title;

  final String url;
}
