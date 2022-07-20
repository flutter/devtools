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

    await _inspector.init();

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
  ValueListenable<List<String>> get customPubRootDirectories =>
      _customPubRootDirectories;
  ValueListenable<bool> get isRefreshingCustomPubRootDirectories =>
      _customPubRootDirectoriesAreBusy;
  InspectorService get inspectorService =>
      serviceManager.inspectorService as InspectorService;

  final _hoverEvalMode = ValueNotifier<bool>(false);
  final _customPubRootDirectories = ListValueNotifier<String>([]);
  final _customPubRootDirectoriesAreBusy = ValueNotifier<bool>(false);
  final _busyCounter = ValueNotifier<int>(0);
  static const _hoverEvalModeStorageId = 'inspector.hoverEvalMode';
  static const _customPubRootDirectoriesStorageId =
      'inspector.customPubRootDirectories';

  Future<void> init() async {
    await initHoverEvalMode();
    _initCustomPubRootListeners();
  }

  Future<void> initHoverEvalMode() async {
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

  void _initCustomPubRootListeners() {
    addAutoDisposeListener(_customPubRootDirectories, () {
      storage.setValue(
        _customPubRootDirectoriesStorageId,
        jsonEncode(_customPubRootDirectories.value),
      );
    });
    addAutoDisposeListener(_busyCounter, () {
      _customPubRootDirectoriesAreBusy.value = _busyCounter.value != 0;
    });
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    await _customPubRootDirectoryBusyTracker(() async {
      await inspectorService.addPubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> removePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    await _customPubRootDirectoryBusyTracker(() async {
      await inspectorService.removePubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> _refreshPubRootDirectoriesFromService() async {
    await _customPubRootDirectoryBusyTracker(() async {
      final freshPubRootDirectories =
          await inspectorService.getPubRootDirectories();
      if (freshPubRootDirectories != null) {
        final newSet = Set<String>.from(freshPubRootDirectories);
        final oldSet = Set<String>.from(_customPubRootDirectories.value);
        final directoriesToAdd = newSet.difference(oldSet);
        final directoriesToRemove = oldSet.difference(newSet);

        _customPubRootDirectories.removeAll(directoriesToRemove);
        _customPubRootDirectories.addAll(directoriesToAdd);
      }
    });
  }

  Future<void> loadCustomPubRootDirectories() async {
    await _customPubRootDirectoryBusyTracker(() async {
      final storedCustomPubRootDirectories =
          await storage.getValue(_customPubRootDirectoriesStorageId);

      if (storedCustomPubRootDirectories != null) {
        await addPubRootDirectories(
          List<String>.from(
            jsonDecode(storedCustomPubRootDirectories),
          ),
        );
      }
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
