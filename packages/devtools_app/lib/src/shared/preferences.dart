// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

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

  MemoryPreferencesController get memory => _memory;
  final _memory = MemoryPreferencesController();

  MemoryPreferencesController get memoryPreferences => _memoryPreferences;
  final _memoryPreferences = MemoryPreferencesController();

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
    await _memory.init();

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

  final _hoverEvalMode = ValueNotifier<bool>(false);
  static const _hoverEvalModeStorageId = 'inspector.hoverEvalMode';

  Future<void> init() async {
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

    setGlobal(InspectorPreferencesController, this);
  }

  /// Change the value for the hover eval mode setting.
  void setHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
  }
}

class MemoryPreferencesController {
  ValueListenable<bool> get androidCollectionEnabled =>
      _androidCollectionEnabled;

  final _androidCollectionEnabled = ValueNotifier<bool>(false);
  static const _androidCollectionEnabledStorageId =
      'memory.androidCollectionEnabled';

  Future<void> init() async {
    final androidCollectionEnabled =
        await storage.getValue(_androidCollectionEnabledStorageId);

    setAndroidCollectionEnabled(androidCollectionEnabled == 'true');

    _androidCollectionEnabled.addListener(() {
      storage.setValue(
        _androidCollectionEnabledStorageId,
        _androidCollectionEnabled.value.toString(),
      );
    });

    setGlobal(InspectorPreferencesController, this);
  }

  /// Change the value for the hover eval mode setting.
  void setAndroidCollectionEnabled(bool enable) {
    _androidCollectionEnabled.value = enable;
  }
}
