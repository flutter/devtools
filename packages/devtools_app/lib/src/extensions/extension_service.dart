// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';

import '../shared/globals.dart';
import '../shared/primitives/auto_dispose.dart';

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  void initialize() {
    addAutoDisposeListener(serviceManager.connectedState, () {
      _refreshAvailableExtensions();
    });
  }

  // TODO(kenz): actually look up the available extensions from devtools server,
  // based on the root path(s) from the available isolate(s).
  int _count = 0;
  void _refreshAvailableExtensions() {
    _availableExtensions.value =
        debugExtensions.sublist(0, _count++ % (debugExtensions.length + 1));
  }
}

// TODO(kenz): remove these once the DevTools extensions feature has shipped.
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
