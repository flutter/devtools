// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../ui/theme.dart';

/// A controller for global application preferences.
class PreferencesController {
  PreferencesController() {
    if (storage == null) {
      // This can happen when running tests.
      log('PreferencesController: storage not initialized');
      return;
    }

    // Get the current values and listen for and write back changes.
    storage.getValue('ui.darkMode').then((String value) {
      darkModeTheme.value = value == null || value == 'true';
      darkModeTheme.addListener(() {
        setTheme(darkTheme: darkModeTheme.value);
        storage.setValue('ui.darkMode', '${darkModeTheme.value}');
      });
    });

    storage.getValue('analytics.enabled').then((String value) {
      analyticsEnabled.value = value == 'true';
      analyticsEnabled.addListener(() {
        storage.setValue('analytics.enabled', '${analyticsEnabled.value}');
      });
    });
  }

  final ValueNotifier<bool> darkModeTheme = ValueNotifier(true);
  final ValueNotifier<bool> analyticsEnabled = ValueNotifier(false);

  void dispose() {
    // Nothing to do here.
  }
}
