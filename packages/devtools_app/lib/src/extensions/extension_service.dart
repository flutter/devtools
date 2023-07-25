// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../shared/config_specific/server/server.dart' as server;
import '../shared/globals.dart';
import '../shared/primitives/auto_dispose.dart';
import 'extension_model.dart';

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  Future<void> initialize() async {
    await maybeRefreshExtensions();
    addAutoDisposeListener(serviceManager.connectedState, () async {
      await maybeRefreshExtensions();
    });

    // TODO(kenz): we should also refresh the available extensions on some event
    // from the analysis server that is watching the
    // .dart_tool/package_config.json file for changes.
  }

  Future<void> maybeRefreshExtensions() async {
    final appRootPath = await _connectedAppRootPath();
    if (appRootPath != null) {
      await _refreshAvailableExtensions(appRootPath);
    }
  }

  Future<void> _refreshAvailableExtensions(String? rootPath) async {
    final extensions = await server.refreshAvailableExtensions(rootPath);
    _availableExtensions.value = extensions;
  }
}

Future<String?> _connectedAppRootPath() async {
  var fileUri = await serviceManager.rootLibraryForSelectedIsolate();
  if (fileUri == null) return null;

  if (fileUri.endsWith('/lib/main.dart')) {
    fileUri = fileUri.replaceFirst('/lib/main.dart', '');
  }
  return fileUri;
}
