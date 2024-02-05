// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:meta/meta.dart';

import 'globals.dart';
import 'survey.dart';

/// Enable this flag to debug analytics when DevTools is run in debug or profile
/// mode, otherwise analytics will only be sent in release builds.
///
/// `ga.isAnalyticsEnabled()` still must return true for analytics to be sent.
bool debugAnalytics = false;

/// Whether to build DevTools for conveniently debugging DevTools extensions.
///
/// Turning this flag to [true] allows for debugging the extensions framework
/// without a server connection.
///
/// This flag should never be checked in with a value of true - this is covered
/// by a test.
final debugDevToolsExtensions =
    _debugDevToolsExtensions || integrationTestMode || testMode || stagerMode;
const _debugDevToolsExtensions = false;

List<DevToolsExtensionConfig> debugHandleRefreshAvailableExtensions(
  // ignore: avoid-unused-parameters, false positive due to conditional imports
  Uri appRoot,
) {
  return debugExtensions;
}

ExtensionEnabledState debugHandleExtensionEnabledState({
  // ignore: avoid-unused-parameters, false positive due to conditional imports
  required Uri appRoot,
  required String extensionName,
  bool? enable,
}) {
  if (enable != null) {
    stubExtensionEnabledStates[extensionName] =
        enable ? ExtensionEnabledState.enabled : ExtensionEnabledState.disabled;
  }
  return stubExtensionEnabledStates.putIfAbsent(
    extensionName,
    () => ExtensionEnabledState.none,
  );
}

@visibleForTesting
void resetDevToolsExtensionEnabledStates() =>
    stubExtensionEnabledStates.clear();

/// Stubbed activation states so we can develop DevTools extensions without a
/// server connection.
final stubExtensionEnabledStates = <String, ExtensionEnabledState>{};

/// Stubbed extensions so we can develop DevTools Extensions without a server
/// connection.
final List<DevToolsExtensionConfig> debugExtensions = [
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'foo',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.pathKey: '/path/to/foo',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'bar',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '2.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
    DevToolsExtensionConfig.pathKey: '/path/to/bar',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'provider',
    DevToolsExtensionConfig.issueTrackerKey:
        'https://github.com/rrousselGit/provider/issues',
    DevToolsExtensionConfig.versionKey: '3.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe50a,
    DevToolsExtensionConfig.pathKey: '/path/to/provider',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
  }),
];

/// Enable this flag to debug the DevTools survey logic.
///
/// When this flag is true, [debugSurveyMetadata] will be used instead of what
/// we normally fetch from
/// 'docs.flutter.dev/f/dart-devtools-survey-metadata.json'.
bool debugSurvey = false;

/// The survey metadata that will be used instead of the live data from
/// 'docs.flutter.dev/f/dart-devtools-survey-metadata.json' when [debugSurvey]
/// is true;
final debugSurveyMetadata = DevToolsSurvey.parse(
  {
    '_comments': [
      'uniqueId must be updated with each new survey so DevTools knows to re-prompt users.',
      'title should not exceed 45 characters.',
      'startDate and endDate should follow ISO 8601 standard with a timezone offset.',
    ],
    'uniqueId': '2023-Q4',
    'title': 'Help improve DevTools! Take our 2023 Q4 survey.',
    'url': 'https://google.qualtrics.com/jfe/form/SV_2l4XcyscF8mQtDM',
    'startDate': '2023-09-20T09:00:00-07:00',
    'endDate': '2023-10-20T09:00:00-07:00',
  },
);
