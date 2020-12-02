// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import '../../utils.dart';

const unsupportedMessage =
    'Unsupported RPC: The DevTools Server is not available on Desktop';

bool get isDevToolsServerAvailable => false;

Future<bool> isFirstRun() async {
  throw Exception(unsupportedMessage);
}

Future<bool> isAnalyticsEnabled() async {
  throw Exception(unsupportedMessage);
}

Future<bool> setAnalyticsEnabled([bool value = true]) async {
  throw Exception(unsupportedMessage);
}

Future<String> flutterGAClientID() async {
  throw Exception(unsupportedMessage);
}

Future<bool> setActiveSurvey(String value) async {
  throw Exception(unsupportedMessage);
}

Future<bool> surveyActionTaken() async {
  throw Exception(unsupportedMessage);
}

Future<void> setSurveyActionTaken() async {
  throw Exception(unsupportedMessage);
}

Future<int> surveyShownCount() async {
  throw Exception(unsupportedMessage);
}

Future<int> incrementSurveyShownCount() async {
  throw Exception(unsupportedMessage);
}

Future<void> resetDevToolsFile() async {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile> requestBaseAppSizeFile(String path) async {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile> requestTestAppSizeFile(String path) async {
  throw Exception(unsupportedMessage);
}

void logWarning() {
  throw Exception(unsupportedMessage);
}
