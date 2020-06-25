// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'config_specific/logger/logger.dart';
import 'globals.dart';

/// A controller for global application preferences.
class PreferencesController {
  final ValueNotifier<bool> _darkModeTheme = ValueNotifier(true);

  ValueListenable get darkModeTheme => _darkModeTheme;

  Future<void> init() async {
    if (storage == null) {
      // This can happen when running tests.
      log('PreferencesController: storage not initialized');
      return;
    }

    // Get the current values and listen for and write back changes.
    final String value = await storage.getValue('ui.darkMode');
    _darkModeTheme.value = value == null || value == 'true';
    _darkModeTheme.addListener(() {
      storage.setValue('ui.darkMode', '${_darkModeTheme.value}');
    });
  }

  /// Change the value for the dark mode setting.
  void toggleDarkModeTheme(bool useDarkMode) {
    _darkModeTheme.value = useDarkMode;
  }
}
