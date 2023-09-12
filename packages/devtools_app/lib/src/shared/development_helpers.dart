// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';

/// Whether to build DevTools for conveniently debugging DevTools extensions.
///
/// Turning this flag to [true] allows for debugging the extensions framework
/// without a server connection.
///
/// This flag should never be checked in with a value of true - this is covered
/// by a test.
const debugDevToolsExtensions = false;

List<DevToolsExtensionConfig> debugHandleRefreshAvailableExtensions(
  String rootPath,
) {
  return debugExtensions;
}

ExtensionEnabledState debugHandleExtensionEnabledState({
  required String rootPath,
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
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'bar',
    DevToolsExtensionConfig.issueTrackerKey: 'www.google.com',
    DevToolsExtensionConfig.versionKey: '2.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe638,
    DevToolsExtensionConfig.pathKey: '/path/to/bar',
  }),
  DevToolsExtensionConfig.parse({
    DevToolsExtensionConfig.nameKey: 'provider',
    DevToolsExtensionConfig.issueTrackerKey:
        'https://github.com/rrousselGit/provider/issues',
    DevToolsExtensionConfig.versionKey: '3.0.0',
    DevToolsExtensionConfig.materialIconCodePointKey: 0xe50a,
    DevToolsExtensionConfig.pathKey: '/path/to/provider',
  }),
];
