// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// Avoid unused parameters does not understand conditional imports.
// ignore_for_file: avoid-unused-parameters
import 'dart:async';

import 'package:devtools_shared/devtools_extensions.dart';

import '../../development_helpers.dart';
import '../../primitives/utils.dart';

const unsupportedMessage =
    'Unsupported RPC: The DevTools Server is not available on Desktop';

bool get isDevToolsServerAvailable => false;

// This is used in g3.
Future<Object?> request(String url) async {
  throw Exception(unsupportedMessage);
}

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

Future<String> getLastShownReleaseNotesVersion() async {
  throw Exception(unsupportedMessage);
}

Future<String> setLastShownReleaseNotesVersion(String version) async {
  throw Exception(unsupportedMessage);
}

// currently unused
Future<void> resetDevToolsFile() async {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile?> requestBaseAppSizeFile(String path) async {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile?> requestTestAppSizeFile(String path) async {
  throw Exception(unsupportedMessage);
}

Future<List<DevToolsExtensionConfig>> refreshAvailableExtensions(
  String rootPath,
) async {
  return debugHandleRefreshAvailableExtensions(rootPath);
}

Future<ExtensionEnabledState> extensionEnabledState({
  required String rootPath,
  required String extensionName,
  bool? enable,
}) async {
  return debugHandleExtensionEnabledState(
    rootPath: rootPath,
    extensionName: extensionName,
    enable: enable,
  );
}

Future<List<String>> requestAndroidBuildVariants(String path) async =>
    const <String>[];

void logWarning() {
  throw Exception(unsupportedMessage);
}
