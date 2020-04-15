// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../ui/theme.dart' as devtools_theme;

// TODO(devoncarew): This controller is currently backed by a global in
// devtools_theme. A future refactor will instead provide a backing store on
// disk.

/// A controller for global application preferences.
class PreferencesController {
  PreferencesController() {
    _init();
  }

  final ValueNotifier<bool> _darkModeTheme =
      ValueNotifier(devtools_theme.isDarkTheme);

  ValueListenable get darkModeTheme => _darkModeTheme;

  void _init() {
    // TODO(devoncarew): Enable when we have storage backed settings.
    //if (storage == null) {
    //  // This can happen when running tests.
    //  log('PreferencesController: storage not initialized');
    //  return;
    //}

    // TODO(devoncarew): Enable when we have storage backed settings.
    // Get the current values and listen for and write back changes.
    //storage.getValue('ui.darkMode').then((String value) {
    //  darkModeTheme.value = value == null || value == 'true';
    //  darkModeTheme.addListener(() {
    //    setTheme(darkTheme: darkModeTheme.value);
    //    storage.setValue('ui.darkMode', '${darkModeTheme.value}');
    //  });
    //});

    _darkModeTheme.addListener(() {
      // ignore: deprecated_member_use_from_same_package
      devtools_theme.setDarkTheme(_darkModeTheme.value);
    });
  }

  /// Change the value for the dark mode setting.
  void toggleDarkModeTheme(bool useDarkMode) {
    _darkModeTheme.value = useDarkMode;
  }
}
