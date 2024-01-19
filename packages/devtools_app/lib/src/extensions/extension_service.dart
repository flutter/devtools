// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';

import '../shared/globals.dart';
import '../shared/server/server.dart' as server;

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ExtensionService({this.fixedAppRootPath});

  /// The fixed (unchanging) root path for the application this
  /// [ExtensionService] will manage DevTools extensions for.
  ///
  /// When null, the root path will instead be calculated from the
  /// [serviceManager]'s currently connected app. See [_initRootPath].
  final String? fixedAppRootPath;

  /// The root path for the Dart / Flutter application this [ExtensionService]
  /// will manage DevTools extensions for.
  String? _rootPath;

  /// All the DevTools extensions that are available for the connected
  /// application, regardless of whether they have been enabled or disabled
  /// by the user.
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  /// DevTools extensions that are visible in their own DevTools screen (i.e.
  /// extensions that have not been manually disabled by the user).
  ValueListenable<List<DevToolsExtensionConfig>> get visibleExtensions =>
      _visibleExtensions;
  final _visibleExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  /// Returns the [ValueListenable] that stores the [ExtensionEnabledState] for
  /// the DevTools Extension with [extensionName].
  ValueListenable<ExtensionEnabledState> enabledStateListenable(
    String extensionName,
  ) {
    return _extensionEnabledStates.putIfAbsent(
      extensionName.toLowerCase(),
      () => ValueNotifier<ExtensionEnabledState>(
        ExtensionEnabledState.none,
      ),
    );
  }

  /// Whether extensions are actively being refreshed by the DevTools server.
  ValueListenable<bool> get refreshInProgress => _refreshInProgress;
  final _refreshInProgress = ValueNotifier(false);

  final _extensionEnabledStates =
      <String, ValueNotifier<ExtensionEnabledState>>{};

  Future<void> initialize() async {
    await _initRootPath();
    await _maybeRefreshExtensions();

    cancelListeners();

    // We only need to add VM service manager related listeners when we are
    // interacting with the currently connected app (i.e. when
    // [fixedAppRootPath] is null).
    if (fixedAppRootPath == null) {
      addAutoDisposeListener(
        serviceConnection.serviceManager.connectedState,
        () async {
          if (serviceConnection.serviceManager.connectedState.value.connected) {
            await _initRootPath();
            await _maybeRefreshExtensions();
          } else {
            _reset();
          }
        },
      );

      // TODO(https://github.com/flutter/flutter/issues/134470): refresh on
      // hot reload and hot restart events instead.
      addAutoDisposeListener(
        serviceConnection.serviceManager.isolateManager.mainIsolate,
        () async {
          if (serviceConnection
                  .serviceManager.isolateManager.mainIsolate.value !=
              null) {
            await _initRootPath();
            await _maybeRefreshExtensions();
          } else {
            _reset();
          }
        },
      );
    }

    addAutoDisposeListener(
      preferences.devToolsExtensions.showOnlyEnabledExtensions,
      () async {
        await _refreshExtensionEnabledStates();
      },
    );

    // TODO(kenz): we should also refresh the available extensions on some event
    // from the analysis server that is watching the
    // .dart_tool/package_config.json file for changes.
  }

  Future<void> _initRootPath() async {
    _rootPath = fixedAppRootPath ?? await _connectedAppRootPath();
  }

  Future<void> _maybeRefreshExtensions() async {
    if (_rootPath == null) return;

    _refreshInProgress.value = true;
    _availableExtensions.value =
        await server.refreshAvailableExtensions(_rootPath!)
          ..sort();
    await _refreshExtensionEnabledStates();
    _refreshInProgress.value = false;
  }

  Future<void> _refreshExtensionEnabledStates() async {
    if (_rootPath == null) return;

    final onlyIncludeEnabled =
        preferences.devToolsExtensions.showOnlyEnabledExtensions.value;

    final visible = <DevToolsExtensionConfig>[];
    for (final extension in _availableExtensions.value) {
      final stateFromOptionsFile = await server.extensionEnabledState(
        rootPath: _rootPath!,
        extensionName: extension.name,
      );
      final stateNotifier = _extensionEnabledStates.putIfAbsent(
        extension.name,
        () => ValueNotifier<ExtensionEnabledState>(stateFromOptionsFile),
      );
      stateNotifier.value = stateFromOptionsFile;

      final shouldIncludeInVisible = onlyIncludeEnabled
          ? stateFromOptionsFile == ExtensionEnabledState.enabled
          : stateFromOptionsFile != ExtensionEnabledState.disabled;
      if (shouldIncludeInVisible) {
        visible.add(extension);
      }
    }
    // [_visibleExtensions] should be set last so that all extension states in
    // [_extensionEnabledStates] are updated by the time we notify listeners of
    // [visibleExtensions]. It is not necessary to sort [visible] because
    // [_availableExtensions] is already sorted.
    _visibleExtensions.value = visible;
  }

  /// Sets the enabled state for [extension].
  Future<void> setExtensionEnabledState(
    DevToolsExtensionConfig extension, {
    required bool enable,
  }) async {
    if (_rootPath == null) return;

    await server.extensionEnabledState(
      rootPath: _rootPath!,
      extensionName: extension.name,
      enable: enable,
    );
    await _refreshExtensionEnabledStates();
  }

  void _reset() {
    _rootPath = null;
    _availableExtensions.value = [];
    _visibleExtensions.value = [];
    _extensionEnabledStates.clear();
    _refreshInProgress.value = false;
  }
}

// TODO(kenz): consider caching this for the duration of the VM service
// connection.
Future<String?> _connectedAppRootPath() async {
  var fileUri = await serviceConnection.rootLibraryForMainIsolate();
  if (fileUri == null) return null;

  // TODO(kenz): for robustness, consider sending the root library uri to the
  // server and having the server look for the package folder that contains the
  // `.dart_tool` directory.

  final directoryRegExp =
      RegExp(r'\/(lib|integration_test|test|bin)\/[^\/.]*.dart');
  final directoryIndex = fileUri.indexOf(directoryRegExp);
  if (directoryIndex != -1) {
    fileUri = fileUri.substring(0, directoryIndex);
  }

  return fileUri;
}
