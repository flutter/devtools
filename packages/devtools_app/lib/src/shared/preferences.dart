// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../service/vm_service_wrapper.dart';
import 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart' as gac;
import 'config_specific/logger/logger_helpers.dart';
import 'constants.dart';
import 'diagnostics/inspector_service.dart';
import 'globals.dart';
import 'primitives/auto_dispose.dart';
import 'primitives/utils.dart';

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

  CpuProfilerPreferencesController get cpuProfiler => _cpuProfiler;
  final _cpuProfiler = CpuProfilerPreferencesController();

  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    String? value = await storage.getValue('ui.darkMode');
    final useDarkMode = value == null || value == 'true';
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
    await cpuProfiler.init();

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
    cpuProfiler.dispose();
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
  ListValueNotifier<String> get customPubRootDirectories =>
      _customPubRootDirectories;
  ValueListenable<bool> get isRefreshingCustomPubRootDirectories =>
      _customPubRootDirectoriesAreBusy;
  InspectorService? get _inspectorService =>
      serviceManager.inspectorService as InspectorService?;

  final _hoverEvalMode = ValueNotifier<bool>(false);
  final _customPubRootDirectories = ListValueNotifier<String>([]);
  final _customPubRootDirectoriesAreBusy = ValueNotifier<bool>(false);
  final _busyCounter = ValueNotifier<int>(0);
  static const _hoverEvalModeStorageId = 'inspector.hoverEvalMode';
  static const _customPubRootDirectoriesStoragePrefix =
      'inspector.customPubRootDirectories';
  String? _mainScriptDir;

  Future<void> _updateMainScriptRef() async {
    final rootLibUriString =
        (await serviceManager.tryToDetectMainRootInfo())?.library;
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
    _initCustomPubRootDirectories();
  }

  Future<void> _initHoverEvalMode() async {
    String? hoverEvalModeEnabledValue =
        await storage.getValue(_hoverEvalModeStorageId);

    // When embedded, default hoverEvalMode to off
    hoverEvalModeEnabledValue ??= (!ideTheme.embed).toString();
    setHoverEvalMode(hoverEvalModeEnabledValue == 'true');

    addAutoDisposeListener(_hoverEvalMode, () {
      storage.setValue(
        _hoverEvalModeStorageId,
        _hoverEvalMode.value.toString(),
      );
    });
  }

  void _initCustomPubRootDirectories() {
    autoDisposeStreamSubscription(
      serviceManager.onConnectionAvailable
          .listen(_handleConnectionToNewService),
    );
    autoDisposeStreamSubscription(
      serviceManager.onConnectionClosed.listen(_handleConnectionClosed),
    );
    addAutoDisposeListener(_busyCounter, () {
      _customPubRootDirectoriesAreBusy.value = _busyCounter.value != 0;
    });
    addAutoDisposeListener(
      serviceManager.isolateManager.mainIsolate,
      () {
        if (_mainScriptDir != null &&
            serviceManager.isolateManager.mainIsolate.value != null) {
          final debuggerState = serviceManager.isolateManager.mainIsolateState;

          if (debuggerState?.isPaused.value == false) {
            // the isolate is already unpaused, we can try to load
            // the directories
            unawaited(preferences.inspector.loadCustomPubRootDirectories());
          } else {
            late Function() pausedListener;

            pausedListener = () {
              if (debuggerState?.isPaused.value == false) {
                unawaited(preferences.inspector.loadCustomPubRootDirectories());

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

  void _handleConnectionClosed(Object? _) {
    _mainScriptDir = null;
    _customPubRootDirectories.clear();
  }

  Future<void> _handleConnectionToNewService(VmServiceWrapper _) async {
    await _updateMainScriptRef();

    _customPubRootDirectories.clear();
    await loadCustomPubRootDirectories();

    if (_customPubRootDirectories.value.isEmpty) {
      // If there are no pub root directories set on the first connection
      // then try inferring them.
      await _customPubRootDirectoryBusyTracker(() async {
        await _inspectorService?.inferPubRootDirectoryIfNeeded();
        await loadCustomPubRootDirectories();
      });
    }
  }

  void _persistCustomPubRootDirectoriesToStorage() {
    unawaited(
      storage.setValue(
        _customPubRootStorageId(),
        jsonEncode(_customPubRootDirectories.value),
      ),
    );
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    // TODO(https://github.com/flutter/devtools/issues/4380):
    // Add validation to EditableList Input.
    // Directories of just / will break the inspector tree local package checks.
    pubRootDirectories.removeWhere(
      (element) => RegExp('^[/\\s]*\$').firstMatch(element) != null,
    );

    if (!serviceManager.hasConnection) return;
    await _customPubRootDirectoryBusyTracker(() async {
      final inspectorService = _inspectorService;
      if (inspectorService == null) return;

      await inspectorService.addPubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> removePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    if (!serviceManager.hasConnection) return;
    await _customPubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService == null) return;

      await localInspectorService.removePubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> _refreshPubRootDirectoriesFromService() async {
    await _customPubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService == null) return;

      final freshPubRootDirectories =
          await localInspectorService.getPubRootDirectories();
      if (freshPubRootDirectories != null) {
        final newSet = Set<String>.of(freshPubRootDirectories);
        final oldSet = Set<String>.of(_customPubRootDirectories.value);
        final directoriesToAdd = newSet.difference(oldSet);
        final directoriesToRemove = oldSet.difference(newSet);

        _customPubRootDirectories.removeAll(directoriesToRemove);
        _customPubRootDirectories.addAll(directoriesToAdd);

        _persistCustomPubRootDirectoriesToStorage();
      }
    });
  }

  String _customPubRootStorageId() {
    assert(_mainScriptDir != null);
    final packageId = _mainScriptDir ?? '_fallback';
    return '${_customPubRootDirectoriesStoragePrefix}_$packageId';
  }

  Future<void> loadCustomPubRootDirectories() async {
    if (!serviceManager.hasConnection) return;

    await _customPubRootDirectoryBusyTracker(() async {
      final storedCustomPubRootDirectories =
          await storage.getValue(_customPubRootStorageId());

      if (storedCustomPubRootDirectories != null) {
        await addPubRootDirectories(
          List<String>.from(
            jsonDecode(storedCustomPubRootDirectories),
          ),
        );
      }
      await _refreshPubRootDirectoriesFromService();
    });
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

class CpuProfilerPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final displayTreeGuidelines = ValueNotifier<bool>(false);

  static final _displayTreeGuidelinesId = '${gac.cpuProfiler}.'
      '${gac.CpuProfilerEvents.cpuProfileDisplayTreeGuidelines.name}';

  Future<void> init() async {
    addAutoDisposeListener(
      displayTreeGuidelines,
      () {
        storage.setValue(
          _displayTreeGuidelinesId,
          displayTreeGuidelines.value.toString(),
        );
        ga.select(
          gac.cpuProfiler,
          gac.CpuProfilerEvents.cpuProfileDisplayTreeGuidelines.name,
          value: displayTreeGuidelines.value ? 1 : 0,
        );
      },
    );
    displayTreeGuidelines.value =
        await storage.getValue(_displayTreeGuidelinesId) == 'true';
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
