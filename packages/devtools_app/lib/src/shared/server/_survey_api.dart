// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'server.dart';

/// Set DevTools parameter value for the active survey (e.g. 'Q1-2020').
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// This method must be called before calling other survey related methods
/// ([isSurveyActionTaken], [setSurveyActionTaken], [surveyShownCount],
/// [incrementSurveyShownCount]). If the active survey is not set, warnings are
/// logged.
Future<bool> setActiveSurvey(String value) async {
  if (isDevToolsServerAvailable) {
    final resp = await request(
      '${SurveyApi.setActiveSurvey}'
      '?$apiParameterValueKey=$value',
    );
    if ((resp?.statusOk ?? false) && json.decode(resp!.body)) {
      return true;
    } else {
      logWarning(resp, SurveyApi.setActiveSurvey);
    }
  }
  return false;
}

/// Request DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<bool> surveyActionTaken() async {
  bool surveyActionTaken = false;

  if (isDevToolsServerAvailable) {
    final resp = await request(SurveyApi.getSurveyActionTaken);
    if (resp?.statusOk ?? false) {
      surveyActionTaken = json.decode(resp!.body);
    } else {
      logWarning(resp, SurveyApi.getSurveyActionTaken);
    }
  }

  return surveyActionTaken;
}

/// Set DevTools property value 'surveyActionTaken' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<void> setSurveyActionTaken() async {
  if (isDevToolsServerAvailable) {
    final resp = await request(SurveyApi.setSurveyActionTaken);
    if (resp == null || !resp.statusOk || !(json.decode(resp.body) as bool)) {
      logWarning(resp, SurveyApi.setSurveyActionTaken);
    }
  }
}

/// Request DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> surveyShownCount() async {
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await request(SurveyApi.getSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, SurveyApi.getSurveyShownCount);
    }
  }

  return surveyShownCount;
}

/// Increment DevTools property value 'surveyShownCount' for the active survey.
///
/// The value is stored in the file '~/.flutter-devtools/.devtools'.
///
/// Requires [setActiveSurvey] to have been called prior to calling this method.
Future<int> incrementSurveyShownCount() async {
  // Any failure will still return 0.
  int surveyShownCount = 0;

  if (isDevToolsServerAvailable) {
    final resp = await request(SurveyApi.incrementSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, SurveyApi.incrementSurveyShownCount);
    }
  }
  return surveyShownCount;
}
