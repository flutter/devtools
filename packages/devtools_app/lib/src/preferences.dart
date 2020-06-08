// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'config_specific/logger/logger.dart';
import 'globals.dart';
import 'ui/theme.dart' as devtools_theme;

/// A controller for global application preferences.
class PreferencesController {
  PreferencesController() {
    _init();
  }

  final ValueNotifier<bool> _darkModeTheme =
      // ignore: deprecated_member_use_from_same_package
      ValueNotifier(devtools_theme.isDarkTheme);

  ValueListenable get darkModeTheme => _darkModeTheme;

  void _init() {
    if (storage == null) {
      // This can happen when running tests.
      log('PreferencesController: storage not initialized');
      return;
    }

    // Get the current values and listen for and write back changes.
    storage.getValue('ui.darkMode').then((String value) {
      _darkModeTheme.value = value == null || value == 'true';
      _darkModeTheme.addListener(() {
        // ignore: deprecated_member_use_from_same_package
        devtools_theme.setTheme(darkTheme: _darkModeTheme.value);
        storage.setValue('ui.darkMode', '${_darkModeTheme.value}');
      });
    });
  }

  /// Change the value for the dark mode setting.
  void toggleDarkModeTheme(bool useDarkMode) {
    _darkModeTheme.value = useDarkMode;
  }
}
