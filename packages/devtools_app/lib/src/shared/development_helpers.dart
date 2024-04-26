// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'globals.dart';
import 'survey.dart';

// This file contains helpers that can be used during local development. Any
// changes to variables in this file (like flipping a bool to true or setting
// a non-null value for a debug String) should be intended for local
// development only, and should never be checked into source control. The
// default values for variables in this file are test covered in
// `development_helpers_test.dart`.

final _log = Logger('dev_helpers');

/// Set this to a real DTD URI String for ease of developing features that use
/// the Dart Tooling Daemon.
///
/// Without using this flag, you would need to run DevTools with the DevTools
/// server (devtools_tool serve) in order to pass a DTD URI to the DevTools
/// server, which is not convenient for development.
///
/// You can use a real DTD URI from an IDE (VS Code or IntelliJ / Android
/// Studio) using the "Copy DTD URI" action, or you can run a Dart or Flutter
/// app from the command line with the `--print-dtd` flag.
String? get debugDtdUri => kReleaseMode ? null : _debugDtdUri;
String? _debugDtdUri;

/// Enable this flag to send and debug analytics when DevTools is run in debug
/// or profile mode, otherwise analytics will only be sent in release builds.
///
/// `ga.isAnalyticsEnabled()` still must return true for analytics to be sent.
bool debugSendAnalytics = false;

/// Enable this flag to always show the analytics consent message, regardless
/// of whether any other conditions are met.
bool debugShowAnalyticsConsentMessage = false;

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

List<DevToolsExtensionConfig> debugHandleRefreshAvailableExtensions({
  bool includeRuntime = true,
}) =>
    StubDevToolsExtensions.extensions(includeRuntime: includeRuntime);

ExtensionEnabledState debugHandleExtensionEnabledState({
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

// ignore: avoid_classes_with_only_static_members, useful for testing.
abstract class StubDevToolsExtensions {
  /// Extension for package:foo detected from a running app that requires a
  /// connected app.
  static final fooExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'foo',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: '0xe0b1',
    DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/foo',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'false',
  });

  /// Extension for package:provider detected from a running app that requires a
  /// connected app.
  static final providerExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'provider',
    DevToolsExtensionConfig.issueTrackerKey:
        'https://github.com/rrousselGit/provider/issues',
    DevToolsExtensionConfig.versionKey: '3.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe50a,
    DevToolsExtensionConfig.extensionAssetsPathKey:
        '/absolute/path/to/provider',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'true',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'false',
  });

  /// Extension for package:some_tool detected from a running app, but that does
  /// not require a connected app.
  static final someToolExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'some_tool',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: '0xe00c',
    DevToolsExtensionConfig.requiresConnectionKey: 'false',
    DevToolsExtensionConfig.extensionAssetsPathKey:
        '/absolute/path/to/some_tool',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'false',
  });

  /// Extension for package:bar detected from a static context that does not
  /// require a connected app.
  static final barExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'bar',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '2.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
    DevToolsExtensionConfig.requiresConnectionKey: 'false',
    DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
  });

  /// Extension for package:bar detected from a static context that does not
  /// require a connected app and that is also a newer version of another static
  /// extension.
  static final newerBarExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'bar',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '2.1.0', // Newer version.
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
    DevToolsExtensionConfig.requiresConnectionKey: 'false',
    DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/bar',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
  });

  /// Extension for package:baz detected from a static context that requires a
  /// connected app.
  static final bazExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'baz',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe716,
    DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/baz',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
  });

  /// Extension for package:foo detected from a static context that is a duplicate
  /// of a runtime extension [fooExtension], which requires a connected app.
  static final duplicateFooExtension = DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'foo',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '1.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: '0xe0b1',
    DevToolsExtensionConfig.extensionAssetsPathKey: '/absolute/path/to/foo',
    DevToolsExtensionConfig.devtoolsOptionsUriKey:
        'file:///path/to/options/file',
    DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
    DevToolsExtensionConfig.detectedFromStaticContextKey: 'true',
  });

  /// Stubbed extensions so we can develop DevTools Extensions without a server
  /// connection.
  static List<DevToolsExtensionConfig> extensions({
    bool includeRuntime = true,
  }) =>
      [
        if (includeRuntime) ...[
          fooExtension,
          providerExtension,
          someToolExtension,
        ],
        barExtension,
        newerBarExtension,
        bazExtension,
        duplicateFooExtension,
      ];
}

/// Enable this flag to debug the DevTools survey logic.
///
/// When this flag is true, [debugSurveyMetadata] will be used instead of what
/// we normally fetch from
/// 'docs.flutter.dev/f/dart-devtools-survey-metadata.json'.
bool debugSurvey = false;

/// The survey metadata that will be used instead of the live data from
/// 'docs.flutter.dev/f/dart-devtools-survey-metadata.json' when [debugSurvey]
/// is true;
final debugSurveyMetadata = DevToolsSurvey.fromJson(
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

/// Enable this flag to debug Perfetto trace processing in the Performance
/// screen.
///
/// When this flag is true, helpful print debugging will be emitted signaling
/// important data for the trace processing logic.
///
/// This flag has performance implications, since printing a lot of data to the
/// command line can be expensive.
const debugPerfettoTraceProcessing = !kReleaseMode && false;

/// Helper method to call a callback only when debugging issues related to trace
/// event duplicates (for example https://github.com/dart-lang/sdk/issues/46605).
void debugTraceCallback(void Function() callback) {
  if (debugPerfettoTraceProcessing) {
    callback();
  }
}

/// Enable this flag to print timing information for callbacks wrapped in
/// [debugTimeSync] or [debugTimeAsync].
const debugTimers = !kReleaseMode && false;

/// Debug helper to run a synchronous [callback] and print the time it took to
/// run to stdout.
///
/// This will only time the operation when [debugTimers] is true.
void debugTimeSync(
  void Function() callback, {
  required String debugName,
}) {
  if (!debugTimers) {
    callback();
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  callback();
  final time = DateTime.now().millisecondsSinceEpoch - now;
  _log.info('$debugName: $time ms');
}

/// Debug helper to run an asynchronous [callback] and print the time it took to
/// run to stdout.
///
/// This will only time the operation when [debugTimers] is true.
FutureOr<void> debugTimeAsync(
  FutureOr<void> Function() callback, {
  required String debugName,
}) async {
  if (!debugTimers) {
    await callback();
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  await callback();
  final time = DateTime.now().millisecondsSinceEpoch - now;
  _log.info('$debugName: $time ms');
}
