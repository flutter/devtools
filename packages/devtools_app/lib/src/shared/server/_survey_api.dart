// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

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
      '$apiSetActiveSurvey'
      '?$activeSurveyName=$value',
    );
    if ((resp?.statusOk ?? false) && json.decode(resp!.body)) {
      return true;
    } else {
      logWarning(resp, apiSetActiveSurvey);
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
    final resp = await request(apiGetSurveyActionTaken);
    if (resp?.statusOk ?? false) {
      surveyActionTaken = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetSurveyActionTaken);
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
    final resp = await request(
      '$apiSetSurveyActionTaken'
      '?$surveyActionTakenPropertyName=true',
    );
    if (resp == null || !resp.statusOk || !(json.decode(resp.body) as bool)) {
      logWarning(resp, apiSetSurveyActionTaken);
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
    final resp = await request(apiGetSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, apiGetSurveyShownCount);
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
    final resp = await request(apiIncrementSurveyShownCount);
    if (resp?.statusOk ?? false) {
      surveyShownCount = json.decode(resp!.body);
    } else {
      logWarning(resp, apiIncrementSurveyShownCount);
    }
  }
  return surveyShownCount;
}
