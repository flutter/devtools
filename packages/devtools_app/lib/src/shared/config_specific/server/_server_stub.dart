// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// Avoid unused parameters does not understand conditional imports.
// ignore_for_file: avoid-unused-parameters
import 'dart:async';

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:devtools_shared/devtools_extensions.dart';

import '../../development_helpers.dart';
import '../../primitives/utils.dart';

const unsupportedMessage =
    'Unsupported RPC: The DevTools Server is not available on Desktop';

bool get isDevToolsServerAvailable => false;

// This is used in g3.
Future<Object?> request(String url) {
  throw Exception(unsupportedMessage);
}

Future<bool> isFirstRun() {
  throw Exception(unsupportedMessage);
}

Future<bool> isAnalyticsEnabled() {
  throw Exception(unsupportedMessage);
}

Future<bool> setAnalyticsEnabled([bool value = true]) {
  throw Exception(unsupportedMessage);
}

Future<String> flutterGAClientID() {
  throw Exception(unsupportedMessage);
}

Future<bool> setActiveSurvey(String value) {
  throw Exception(unsupportedMessage);
}

Future<bool> surveyActionTaken() {
  throw Exception(unsupportedMessage);
}

Future<void> setSurveyActionTaken() {
  throw Exception(unsupportedMessage);
}

Future<int> surveyShownCount() {
  throw Exception(unsupportedMessage);
}

Future<int> incrementSurveyShownCount() {
  throw Exception(unsupportedMessage);
}

Future<String> getLastShownReleaseNotesVersion() {
  throw Exception(unsupportedMessage);
}

Future<String> setLastShownReleaseNotesVersion(String version) {
  throw Exception(unsupportedMessage);
}

// currently unused
Future<void> resetDevToolsFile() {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile?> requestBaseAppSizeFile(String path) {
  throw Exception(unsupportedMessage);
}

Future<DevToolsJsonFile?> requestTestAppSizeFile(String path) {
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

Future<AppLinkSettings> requestAndroidAppLinkSettings(
  String path, {
  required String buildVariant,
}) async =>
    AppLinkSettings.empty;

Future<XcodeBuildOptions> requestIosBuildOptions(String path) async =>
    XcodeBuildOptions.empty;

Future<UniversalLinkSettings> requestIosUniversalLinkSettings(
  String path, {
  required String configuration,
  required String target,
}) async =>
    UniversalLinkSettings.empty;

void logWarning() {
  throw Exception(unsupportedMessage);
}
