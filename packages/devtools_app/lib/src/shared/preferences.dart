// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../primitives/auto_dispose.dart';
import '../primitives/utils.dart';
import '../screens/inspector/inspector_service.dart';
import '../service/vm_service_wrapper.dart';
import 'globals.dart';

/// A controller for global application preferences.
class PreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final ValueNotifier<bool> _darkModeTheme = ValueNotifier(true);
  final ValueNotifier<bool> _vmDeveloperMode = ValueNotifier(false);
  final ValueNotifier<bool> _denseMode = ValueNotifier(false);

  ValueListenable<bool> get darkModeTheme => _darkModeTheme;
  ValueListenable<bool> get vmDeveloperModeEnabled => _vmDeveloperMode;
  ValueListenable<bool> get denseModeEnabled => _denseMode;

  InspectorPreferencesController get inspector => _inspector;

  final _inspector = InspectorPreferencesController();

  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    String? value = await storage.getValue('ui.darkMode');
    toggleDarkModeTheme(value == null || value == 'true');
    addAutoDisposeListener(_darkModeTheme, () {
      storage.setValue('ui.darkMode', '${_darkModeTheme.value}');
    });

    value = await storage.getValue('ui.vmDeveloperMode');
    toggleVmDeveloperMode(value == 'true');
    addAutoDisposeListener(_vmDeveloperMode, () {
      storage.setValue('ui.vmDeveloperMode', '${_vmDeveloperMode.value}');
    });

    value = await storage.getValue('ui.denseMode');
    toggleDenseMode(value == 'true');
    addAutoDisposeListener(_denseMode, () {
      storage.setValue('ui.denseMode', '${_denseMode.value}');
    });

    await inspector.init();

    setGlobal(PreferencesController, this);
  }

  @override
  void dispose() {
    inspector.dispose();
    super.dispose();
  }

  /// Change the value for the dark mode setting.
  void toggleDarkModeTheme(bool useDarkMode) {
    _darkModeTheme.value = useDarkMode;
  }

  /// Change the value for the VM developer mode setting.
  void toggleVmDeveloperMode(bool enableVmDeveloperMode) {
    _vmDeveloperMode.value = enableVmDeveloperMode;
    VmServicePrivate.enablePrivateRpcs = enableVmDeveloperMode;
  }

  /// Change the value for the dense mode setting.
  void toggleDenseMode(bool enableDenseMode) {
    _denseMode.value = enableDenseMode;
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
    final isolateRef = serviceManager.isolateManager.mainIsolate.value!;
    if (isolateRef.id != null) {
      final isolate = await serviceManager.service?.getIsolate(isolateRef.id!);
      final rootLibUri = Uri.parse(isolate?.rootLib?.uri ?? '');
      final directorySegments = rootLibUri.pathSegments
          .sublist(0, rootLibUri.pathSegments.length - 1);
      final rootLibDirectory = rootLibUri.replace(
        pathSegments: directorySegments,
      );
      _mainScriptDir = rootLibDirectory.path;
    }
  }

  Future<void> init() async {
    await _initHoverEvalMode();
    await _initCustomPubRootDirectories();
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

  Future<void> _initCustomPubRootDirectories() async {
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
          final debuggerState =
              serviceManager.isolateManager.mainIsolateDebuggerState;

          if (debuggerState?.isPaused.value == false) {
            // the isolate is already unpaused, we can try to load
            // the directories
            preferences.inspector.loadCustomPubRootDirectories();
          } else {
            late Function() pausedListener;

            pausedListener = () {
              if (debuggerState?.isPaused.value == false) {
                preferences.inspector.loadCustomPubRootDirectories();

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

  void _handleConnectionClosed(dynamic _) async {
    _mainScriptDir = null;
    _customPubRootDirectories.clear();
  }

  Future<void> _handleConnectionToNewService(VmServiceWrapper wrapper) async {
    await _updateMainScriptRef();

    _customPubRootDirectories.clear();
    await loadCustomPubRootDirectories();

    if (_customPubRootDirectories.value.isEmpty) {
      // If there are no pub root directories set on the first connection
      // then try inferring them.
      await _inspectorService?.inferPubRootDirectoryIfNeeded();
      await loadCustomPubRootDirectories();
    }
  }

  void _persistCustomPubRootDirectoriesToStorage() {
    storage.setValue(
      _customPubRootStorageId(),
      jsonEncode(_customPubRootDirectories.value),
    );
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    // TODO(https://github.com/flutter/devtools/issues/4380):
    // Add validation to EditableList Input.
    // Directories of just / will break the inspector tree local package checks.
    pubRootDirectories.removeWhere(
      (element) => element.replaceAll(RegExp('\/'), '').trim() == '',
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
        final newSet = Set<String>.from(freshPubRootDirectories);
        final oldSet = Set<String>.from(_customPubRootDirectories.value);
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
