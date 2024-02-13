// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../devtools_app.dart';
import '../shared/globals.dart';
import '../shared/server/server.dart' as server;

final _log = Logger('ExtensionService');

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ExtensionService({this.fixedAppRoot});

  /// The fixed (unchanging) root file:// URI for the application this
  /// [ExtensionService] will manage DevTools extensions for.
  ///
  /// When null, the root will be calculated from the [serviceManager]'s
  /// currently connected app. See [_initAppRoot].
  final Uri? fixedAppRoot;

  /// The root file:// URI for the Dart / Flutter application this
  /// [ExtensionService] will manage DevTools extensions for.
  Uri? _appRoot;

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
    await _initAppRoot();
    await _maybeRefreshExtensions();

    cancelListeners();

    // We only need to add VM service manager related listeners when we are
    // interacting with the currently connected app (i.e. when
    // [fixedAppRootUri] is null).
    if (fixedAppRoot == null) {
      addAutoDisposeListener(
        serviceConnection.serviceManager.connectedState,
        () async {
          if (serviceConnection.serviceManager.connectedState.value.connected) {
            _log.fine(
              'established new app connection. Initializing and refreshing.',
            );
            await _initAppRoot();
            await _maybeRefreshExtensions();
          } else {
            _log.fine('app disconnected. Initializing and refreshing.');
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
            _log.fine('main isolate changed. Initializing and refreshing.');
            await _initAppRoot();
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

  Future<void> _initAppRoot() async {
    _appRoot = fixedAppRoot ?? await _connectedAppRoot();
  }

  Future<void> _maybeRefreshExtensions() async {
    if (_appRoot == null) return;

    _refreshInProgress.value = true;
    _availableExtensions.value =
        await server.refreshAvailableExtensions(_appRoot!)
          ..sort();
    await _refreshExtensionEnabledStates();
    _refreshInProgress.value = false;
  }

  Future<void> _refreshExtensionEnabledStates() async {
    if (_appRoot == null) return;

    final onlyIncludeEnabled =
        preferences.devToolsExtensions.showOnlyEnabledExtensions.value;

    final visible = <DevToolsExtensionConfig>[];
    for (final extension in _availableExtensions.value) {
      final stateFromOptionsFile = await server.extensionEnabledState(
        appRoot: _appRoot!,
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

    _log.fine(
      'visible extensions after refreshing - ${visible.map((e) => e.name).toList()}',
    );

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
    if (_appRoot == null) return;

    await server.extensionEnabledState(
      appRoot: _appRoot!,
      extensionName: extension.name,
      enable: enable,
    );
    await _refreshExtensionEnabledStates();
  }

  void _reset() {
    _appRoot = null;
    _availableExtensions.value = [];
    _visibleExtensions.value = [];
    _extensionEnabledStates.clear();
    _refreshInProgress.value = false;
  }
}

// TODO(kenz): consider caching this for the duration of the VM service
// connection.
Future<Uri?> _connectedAppRoot() async {
  String? fileUriString;
  if (serviceConnection.serviceManager.serviceExtensionManager
      .hasServiceExtension(testTargetLibraryExtension)
      .value) {
    final result = await serviceConnection.serviceManager
        .callServiceExtensionOnMainIsolate(testTargetLibraryExtension);
    fileUriString = result.json?['value'];
    _log.fine(
      'fetched library from $testTargetLibraryExtension: $fileUriString',
    );
  }

  if (fileUriString == null) {
    fileUriString = await serviceConnection.rootLibraryForMainIsolate();
    _log.fine('fetched rootLibraryForMainIsolate: $fileUriString');
  }

  if (fileUriString == null) return null;
  return Uri.parse(rootFromFileUriString(fileUriString));
}

@visibleForTesting
String rootFromFileUriString(String fileUriString) {
  // TODO(kenz): for robustness, consider sending the root library uri to the
  // server and having the server look for the package folder that contains the
  // `.dart_tool` directory.
  final directoryRegExp =
      RegExp(r'\/(lib|bin|integration_test|test|benchmark)\/.+\.dart');
  final directoryIndex = fileUriString.indexOf(directoryRegExp);
  if (directoryIndex != -1) {
    fileUriString = fileUriString.substring(0, directoryIndex);
  }
  _log.fine('calculating rootFromFileUriString: $fileUriString');
  return fileUriString;
}
