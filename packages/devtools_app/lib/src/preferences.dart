// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'config_specific/logger/logger.dart';
import 'globals.dart';
import 'vm_service_wrapper.dart';

/// A controller for global application preferences.
class PreferencesController {
  final ValueNotifier<bool> _darkModeTheme = ValueNotifier(true);
  final ValueNotifier<bool> _vmDeveloperMode = ValueNotifier(false);

  ValueListenable<bool> get darkModeTheme => _darkModeTheme;
  ValueListenable<bool> get vmDeveloperModeEnabled => _vmDeveloperMode;

  Future<void> init() async {
    if (storage != null) {
      // Get the current values and listen for and write back changes.
      String value = await storage.getValue('ui.darkMode');
      toggleDarkModeTheme(value == null || value == 'true');
      _darkModeTheme.addListener(() {
        storage.setValue('ui.darkMode', '${_darkModeTheme.value}');
      });

      value = await storage.getValue('ui.vmDeveloperMode');
      toggleVmDeveloperMode(value == 'true');
      _vmDeveloperMode.addListener(() {
        storage.setValue('ui.vmDeveloperMode', '${_vmDeveloperMode.value}');
      });
    } else {
      // This can happen when running tests.
      log('PreferencesController: storage not initialized');
    }
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
}
