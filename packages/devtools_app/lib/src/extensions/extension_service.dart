// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';

import '../shared/config_specific/server/server.dart' as server;
import '../shared/globals.dart';
import '../shared/primitives/auto_dispose.dart';

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  Future<void> initialize() async {
    await maybeRefreshExtensions();
    addAutoDisposeListener(
      serviceManager.connectedState,
      maybeRefreshExtensions,
    );

    // TODO(kenz): we should also refresh the available extensions on some event
    // from the analysis server that is watching the
    // .dart_tool/package_config.json file for changes.
  }

  Future<void> maybeRefreshExtensions() async {
    final appRootPath = await _connectedAppRootPath();
    if (appRootPath != null) {
      _availableExtensions.value =
          await server.refreshAvailableExtensions(appRootPath);
    }
  }
}

Future<String?> _connectedAppRootPath() async {
  var fileUri = await serviceManager.rootLibraryForSelectedIsolate();
  if (fileUri == null) return null;

  // TODO(kenz): for robustness, consider sending the root library uri to the
  // server and having the server look for the package folder that contains the
  // `.dart_tool` directory.

  // Assume that the parent folder of `lib` is the package root.
  final libDirectoryRegExp = RegExp(r'\/lib\/[^\/.]*.dart');
  final libDirectoryIndex = fileUri.indexOf(libDirectoryRegExp);
  if (libDirectoryIndex != -1) {
    fileUri = fileUri.substring(0, libDirectoryIndex);
  }
  return fileUri;
}
