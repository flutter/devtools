// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../primitives/utils.dart';
import '../screens/inspector/inspector_service.dart';
import '../service/vm_service_wrapper.dart';
import 'globals.dart';

/// A controller for global application preferences.
class PreferencesController {
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
    _darkModeTheme.addListener(() {
      storage.setValue('ui.darkMode', '${_darkModeTheme.value}');
    });

    value = await storage.getValue('ui.vmDeveloperMode');
    toggleVmDeveloperMode(value == 'true');
    _vmDeveloperMode.addListener(() {
      storage.setValue('ui.vmDeveloperMode', '${_vmDeveloperMode.value}');
    });

    value = await storage.getValue('ui.denseMode');
    toggleDenseMode(value == 'true');
    _denseMode.addListener(() {
      storage.setValue('ui.denseMode', '${_denseMode.value}');
    });

    await _inspector.init();

    setGlobal(PreferencesController, this);
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

class InspectorPreferencesController {
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
    setGlobal(InspectorPreferencesController, this);
  }

  Future<void> initHoverEvalMode() async {
    String? hoverEvalModeEnabledValue =
        await storage.getValue(_hoverEvalModeStorageId);

    // When embedded, default hoverEvalMode to off
    hoverEvalModeEnabledValue ??= (!ideTheme.embed).toString();
    setHoverEvalMode(hoverEvalModeEnabledValue == 'true');

    _hoverEvalMode.addListener(() {
      storage.setValue(
        _hoverEvalModeStorageId,
        _hoverEvalMode.value.toString(),
      );
    });
  }

  void _initCustomPubRootListeners() {
    _customPubRootDirectories.addListener(() {
      storage.setValue(
        _customPubRootDirectoriesStorageId,
        jsonEncode(_customPubRootDirectories.value),
      );
    });
    _busyCounter.addListener(() {
      _customPubRootDirectoriesAreBusy.value = _busyCounter.value != 0;
    });
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    await _customPubRootDirectoryBusyTracker(
      Future<void>(() async {
        await inspectorService.addPubRootDirectories(pubRootDirectories);
        await refreshPubRootDirectoriesFromService();
      }),
    );
  }

  Future<void> removePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    await _customPubRootDirectoryBusyTracker(
      Future<void>(() async {
        await inspectorService.removePubRootDirectories(pubRootDirectories);
        await refreshPubRootDirectoriesFromService();
      }),
    );
  }

  Future<void> refreshPubRootDirectoriesFromService() async {
    await _customPubRootDirectoryBusyTracker(
      Future<void>(() async {
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
      }),
    );
  }

  Future<void> loadCustomPubRootDirectoriesFromStorage() async {
    await _customPubRootDirectoryBusyTracker(
      Future<void>(() async {
        final storedCustomPubRootDirectories =
            await storage.getValue(_customPubRootDirectoriesStorageId);

        if (storedCustomPubRootDirectories != null) {
          await addPubRootDirectories(
            List<String>.from(
              jsonDecode(storedCustomPubRootDirectories),
            ),
          );
        }
      }),
    );
  }

  Future<void> _customPubRootDirectoryBusyTracker(Future<void> callback) async {
    try {
      _busyCounter.value++;
      await callback.timeout(const Duration(seconds: 10));
    } finally {
      _busyCounter.value--;
    }
  }

  /// Change the value for the hover eval mode setting.
  void setHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
  }
}
