// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../service/vm_service_wrapper.dart';
import 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart' as gac;
import 'config_specific/logger/logger_helpers.dart';
import 'constants.dart';
import 'diagnostics/inspector_service.dart';
import 'globals.dart';
import 'utils.dart';

const _thirdPartyPathSegment = 'third_party';

/// A controller for global application preferences.
class PreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final darkModeTheme = ValueNotifier<bool>(true);

  final vmDeveloperModeEnabled = ValueNotifier<bool>(false);

  final verboseLoggingEnabled =
      ValueNotifier<bool>(Logger.root.level == verboseLoggingLevel);
  static const _verboseLoggingStorageId = 'verboseLogging';

  final denseModeEnabled = ValueNotifier<bool>(false);

  InspectorPreferencesController get inspector => _inspector;
  final _inspector = InspectorPreferencesController();

  MemoryPreferencesController get memory => _memory;
  final _memory = MemoryPreferencesController();

  PerformancePreferencesController get performance => _performance;
  final _performance = PerformancePreferencesController();

  ExtensionsPreferencesController get devToolsExtensions => _extensions;
  final _extensions = ExtensionsPreferencesController();

  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    String? value = await storage.getValue('ui.darkMode');

    final useDarkMode =
        (value == null && useDarkThemeAsDefault) || value == 'true';
    toggleDarkModeTheme(useDarkMode);
    addAutoDisposeListener(darkModeTheme, () {
      storage.setValue('ui.darkMode', '${darkModeTheme.value}');
    });

    value = await storage.getValue('ui.vmDeveloperMode');
    toggleVmDeveloperMode(value == 'true');
    addAutoDisposeListener(vmDeveloperModeEnabled, () {
      storage.setValue('ui.vmDeveloperMode', '${vmDeveloperModeEnabled.value}');
    });

    value = await storage.getValue('ui.denseMode');
    toggleDenseMode(value == 'true');
    addAutoDisposeListener(denseModeEnabled, () {
      storage.setValue('ui.denseMode', '${denseModeEnabled.value}');
    });

    await _initVerboseLogging();

    await inspector.init();
    await memory.init();
    await performance.init();
    await devToolsExtensions.init();

    setGlobal(PreferencesController, this);
  }

  Future<void> _initVerboseLogging() async {
    final verboseLoggingEnabledValue =
        await storage.getValue(_verboseLoggingStorageId);

    toggleVerboseLogging(verboseLoggingEnabledValue == 'true');

    addAutoDisposeListener(verboseLoggingEnabled, () {
      storage.setValue(
        'verboseLogging',
        verboseLoggingEnabled.value.toString(),
      );

      if (verboseLoggingEnabled.value) {
        setDevToolsLoggingLevel(verboseLoggingLevel);
      } else {
        setDevToolsLoggingLevel(basicLoggingLevel);
      }
    });
  }

  @override
  void dispose() {
    inspector.dispose();
    memory.dispose();
    performance.dispose();
    devToolsExtensions.dispose();
    super.dispose();
  }

  /// Change the value for the dark mode setting.
  void toggleDarkModeTheme(bool? useDarkMode) {
    if (useDarkMode != null) {
      darkModeTheme.value = useDarkMode;
    }
  }

  /// Change the value for the VM developer mode setting.
  void toggleVmDeveloperMode(bool? enableVmDeveloperMode) {
    if (enableVmDeveloperMode != null) {
      vmDeveloperModeEnabled.value = enableVmDeveloperMode;
      VmServiceWrapper.enablePrivateRpcs = enableVmDeveloperMode;
    }
  }

  void toggleVerboseLogging(bool? enableVerboseLogging) {
    if (enableVerboseLogging != null) {
      verboseLoggingEnabled.value = enableVerboseLogging;
    }
  }

  /// Change the value for the dense mode setting.
  void toggleDenseMode(bool? enableDenseMode) {
    if (enableDenseMode != null) {
      denseModeEnabled.value = enableDenseMode;
    }
  }
}

class InspectorPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<bool> get hoverEvalModeEnabled => _hoverEvalMode;
  ListValueNotifier<String> get pubRootDirectories => _pubRootDirectories;
  ValueListenable<bool> get isRefreshingPubRootDirectories =>
      _pubRootDirectoriesAreBusy;
  InspectorServiceBase? get _inspectorService =>
      serviceConnection.inspectorService;

  final _hoverEvalMode = ValueNotifier<bool>(false);
  final _pubRootDirectories = ListValueNotifier<String>([]);
  final _pubRootDirectoriesAreBusy = ValueNotifier<bool>(false);
  final _busyCounter = ValueNotifier<int>(0);
  static const _hoverEvalModeStorageId = 'inspector.hoverEvalMode';
  static const _customPubRootDirectoriesStoragePrefix =
      'inspector.customPubRootDirectories';
  String? _mainScriptDir;

  Future<void> _updateMainScriptRef() async {
    final rootLibUriString =
        (await serviceConnection.serviceManager.tryToDetectMainRootInfo())
            ?.library;
    final rootLibUri = Uri.parse(rootLibUriString ?? '');
    final directorySegments =
        rootLibUri.pathSegments.sublist(0, rootLibUri.pathSegments.length - 1);
    final rootLibDirectory = rootLibUri.replace(
      pathSegments: directorySegments,
    );
    _mainScriptDir = rootLibDirectory.path;
  }

  Future<void> init() async {
    await _initHoverEvalMode();
    // TODO(jacobr): consider initializing this first as it is not blocking.
    _initPubRootDirectories();
  }

  Future<void> _initHoverEvalMode() async {
    await _updateHoverEvalMode();

    addAutoDisposeListener(_hoverEvalMode, () {
      storage.setValue(
        _hoverEvalModeStorageId,
        _hoverEvalMode.value.toString(),
      );
    });
  }

  Future<void> _updateHoverEvalMode() async {
    String? hoverEvalModeEnabledValue =
        await storage.getValue(_hoverEvalModeStorageId);

    hoverEvalModeEnabledValue ??=
        (_inspectorService?.hoverEvalModeEnabledByDefault ?? false).toString();
    setHoverEvalMode(hoverEvalModeEnabledValue == 'true');
  }

  void _initPubRootDirectories() {
    addAutoDisposeListener(
      serviceConnection.serviceManager.connectedState,
      () async {
        if (serviceConnection.serviceManager.connectedState.value.connected) {
          await handleConnectionToNewService();
        } else {
          _handleConnectionClosed();
        }
      },
    );
    addAutoDisposeListener(_busyCounter, () {
      _pubRootDirectoriesAreBusy.value = _busyCounter.value != 0;
    });
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        if (_mainScriptDir != null &&
            serviceConnection.serviceManager.isolateManager.mainIsolate.value !=
                null) {
          final debuggerState =
              serviceConnection.serviceManager.isolateManager.mainIsolateState;

          if (debuggerState?.isPaused.value == false) {
            // the isolate is already unpaused, we can try to load
            // the directories
            unawaited(preferences.inspector.loadPubRootDirectories());
          } else {
            late Function() pausedListener;

            pausedListener = () {
              if (debuggerState?.isPaused.value == false) {
                unawaited(preferences.inspector.loadPubRootDirectories());

                debuggerState?.isPaused.removeListener(pausedListener);
              }
            };

            // The isolate is still paused, listen for when it becomes unpaused.
            addAutoDisposeListener(debuggerState?.isPaused, pausedListener);
          }
        }
      },
    );
  }

  void _handleConnectionClosed() {
    _mainScriptDir = null;
    _pubRootDirectories.clear();
  }

  @visibleForTesting
  Future<void> handleConnectionToNewService() async {
    await _updateMainScriptRef();
    await _updateHoverEvalMode();
    await loadPubRootDirectories();
  }

  Future<void> loadPubRootDirectories() async {
    await _customPubRootDirectoryBusyTracker(() async {
      await addPubRootDirectories(await _determinePubRootDirectories());
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<List<String>> _determinePubRootDirectories() async {
    final cachedDirectories = await _readCachedPubRootDirectories();
    final inferredDirectory = await _inferPubRootDirectory();

    if (inferredDirectory == null) return cachedDirectories;
    return {...cachedDirectories, inferredDirectory}.toList();
  }

  Future<List<String>> _readCachedPubRootDirectories() async {
    final cachedDirectoriesJson =
        await storage.getValue(_customPubRootStorageId());
    if (cachedDirectoriesJson == null) return <String>[];

    return List<String>.from(
      jsonDecode(cachedDirectoriesJson),
    );
  }

  /// As we aren't running from an IDE, we don't know exactly what the pub root
  /// directories are for the current project so we make a best guess based on
  /// the root library for the main isolate.
  Future<String?> _inferPubRootDirectory() async {
    final path = await serviceConnection.rootLibraryForMainIsolate();
    if (path == null) {
      return null;
    }
    // TODO(jacobr): Once https://github.com/flutter/flutter/issues/26615 is
    // fixed we will be able to use package: paths. Temporarily all tools
    // tracking widget locations will need to support both path formats.
    // TODO(jacobr): use the list of loaded scripts to determine the appropriate
    // package root directory given that the root script of this project is in
    // this directory rather than guessing based on url structure.
    final parts = path.split('/');
    String? pubRootDirectory;
    // For google3, we grab the top-level directory in the google3 directory
    // (e.g. /education), or the top-level directory in third_party (e.g.
    // /third_party/dart):
    if (isGoogle3Path(parts)) {
      pubRootDirectory = _pubRootDirectoryForGoogle3(parts);
    } else {
      final parts = path.split('/');

      for (int i = parts.length - 1; i >= 0; i--) {
        final part = parts[i];
        if (part == 'lib' || part == 'web') {
          pubRootDirectory = parts.sublist(0, i).join('/');
          break;
        }

        if (part == 'packages') {
          pubRootDirectory = parts.sublist(0, i + 1).join('/');
          break;
        }
      }
    }
    pubRootDirectory ??= (parts..removeLast()).join('/');
    return pubRootDirectory;
  }

  String? _pubRootDirectoryForGoogle3(List<String> pathParts) {
    final strippedParts = stripGoogle3(pathParts);
    if (strippedParts.isEmpty) return null;

    final topLevelDirectory = strippedParts.first;
    if (topLevelDirectory == _thirdPartyPathSegment &&
        strippedParts.length >= 2) {
      return '/${strippedParts.sublist(0, 2).join('/')}';
    } else {
      return '/${strippedParts.first}';
    }
  }

  void _cacheCustomPubRootDirectories(
    List<String> pubRootDirectories,
  ) {
    unawaited(
      storage.setValue(
        _customPubRootStorageId(),
        jsonEncode(pubRootDirectories),
      ),
    );
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories, {
    bool shouldCache = false,
  }) async {
    // TODO(https://github.com/flutter/devtools/issues/4380):
    // Add validation to EditableList Input.
    // Directories of just / will break the inspector tree local package checks.
    pubRootDirectories.removeWhere(
      (element) => RegExp('^[/\\s]*\$').firstMatch(element) != null,
    );

    if (!serviceConnection.serviceManager.hasConnection) return;
    await _customPubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      await localInspectorService.addPubRootDirectories(pubRootDirectories);
      if (shouldCache) {
        _cacheCustomPubRootDirectories(pubRootDirectories);
      }
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> removePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    if (!serviceConnection.serviceManager.hasConnection) return;
    await _customPubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      await localInspectorService.removePubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> _refreshPubRootDirectoriesFromService() async {
    await _customPubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      final freshPubRootDirectories =
          await localInspectorService.getPubRootDirectories();
      if (freshPubRootDirectories != null) {
        final newSet = Set<String>.of(freshPubRootDirectories);
        final oldSet = Set<String>.of(_pubRootDirectories.value);
        final directoriesToAdd = newSet.difference(oldSet);
        final directoriesToRemove = oldSet.difference(newSet);

        _pubRootDirectories.removeAll(directoriesToRemove);
        _pubRootDirectories.addAll(directoriesToAdd);
      }
    });
  }

  String _customPubRootStorageId() {
    assert(_mainScriptDir != null);
    final packageId = _mainScriptDir ?? '_fallback';
    return '${_customPubRootDirectoriesStoragePrefix}_$packageId';
  }

  Future<void> _customPubRootDirectoryBusyTracker(
    Future<void> Function() callback,
  ) async {
    try {
      _busyCounter.value++;
      await callback();
    } finally {
      _busyCounter.value--;
    }
  }

  /// Change the value for the hover eval mode setting.
  void setHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
  }
}

class MemoryPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// If true, android chart will be shown in addition to
  /// dart chart.
  final androidCollectionEnabled = ValueNotifier<bool>(false);
  static const _androidCollectionEnabledStorageId =
      'memory.androidCollectionEnabled';

  /// If false, mamory chart will be collapsed.
  final showChart = ValueNotifier<bool>(true);
  static const _showChartStorageId = 'memory.showChart';

  /// Number of references to request from vm service,
  /// when browsing references in console.
  final refLimitTitle = 'Limit for number of requested live instances.';
  final refLimit = ValueNotifier<int>(_defaultRefLimit);
  static const _defaultRefLimit = 100000;
  static const _refLimitStorageId = 'memory.refLimit';

  Future<void> init() async {
    addAutoDisposeListener(
      androidCollectionEnabled,
      () {
        storage.setValue(
          _androidCollectionEnabledStorageId,
          androidCollectionEnabled.value.toString(),
        );
        if (androidCollectionEnabled.value) {
          ga.select(
            gac.memory,
            gac.MemoryEvent.chartAndroid,
          );
        }
      },
    );
    androidCollectionEnabled.value =
        await storage.getValue(_androidCollectionEnabledStorageId) == 'true';

    addAutoDisposeListener(
      showChart,
      () {
        storage.setValue(
          _showChartStorageId,
          showChart.value.toString(),
        );

        ga.select(
          gac.memory,
          showChart.value
              ? gac.MemoryEvent.showChart
              : gac.MemoryEvent.hideChart,
        );
      },
    );
    showChart.value = await storage.getValue(_showChartStorageId) != 'false';

    addAutoDisposeListener(
      refLimit,
      () {
        storage.setValue(
          _refLimitStorageId,
          refLimit.value.toString(),
        );

        ga.select(
          gac.memory,
          gac.MemoryEvent.browseRefLimit,
        );
      },
    );
    refLimit.value =
        int.tryParse(await storage.getValue(_refLimitStorageId) ?? '') ??
            _defaultRefLimit;
  }
}

class PerformancePreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final showFlutterFramesChart = ValueNotifier<bool>(true);

  static final _showFlutterFramesChartId =
      '${gac.performance}.${gac.PerformanceEvents.framesChartVisibility.name}';

  Future<void> init() async {
    addAutoDisposeListener(
      showFlutterFramesChart,
      () {
        storage.setValue(
          _showFlutterFramesChartId,
          showFlutterFramesChart.value.toString(),
        );
        ga.select(
          gac.performance,
          gac.PerformanceEvents.framesChartVisibility.name,
          value: showFlutterFramesChart.value ? 1 : 0,
        );
      },
    );
    showFlutterFramesChart.value =
        await storage.getValue(_showFlutterFramesChartId) != 'false';
  }
}

class ExtensionsPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final showOnlyEnabledExtensions = ValueNotifier<bool>(false);

  static final _showOnlyEnabledExtensionsId =
      '${gac.DevToolsExtensionEvents.extensionScreenId}.'
      '${gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name}';

  Future<void> init() async {
    addAutoDisposeListener(
      showOnlyEnabledExtensions,
      () {
        storage.setValue(
          _showOnlyEnabledExtensionsId,
          showOnlyEnabledExtensions.value.toString(),
        );
        ga.select(
          gac.DevToolsExtensionEvents.extensionScreenId.name,
          gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name,
          value: showOnlyEnabledExtensions.value ? 1 : 0,
        );
      },
    );
    // Default the value to false if it is not set.
    showOnlyEnabledExtensions.value =
        await storage.getValue(_showOnlyEnabledExtensionsId) == 'true';
  }
}
