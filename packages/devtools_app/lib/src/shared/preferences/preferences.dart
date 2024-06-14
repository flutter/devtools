// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../service/vm_service_wrapper.dart';
import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as gac;
import '../config_specific/logger/logger_helpers.dart';
import '../constants.dart';
import '../diagnostics/inspector_service.dart';
import '../globals.dart';
import '../utils.dart';

part '_extension_preferences.dart';
part '_inspector_preferences.dart';
part '_inspector_v2_preferences.dart';
part '_memory_preferences.dart';
part '_performance_preferences.dart';

const _thirdPartyPathSegment = 'third_party';

/// A controller for global application preferences.
class PreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final darkModeTheme = ValueNotifier<bool>(true);

  final vmDeveloperModeEnabled = ValueNotifier<bool>(false);

  final verboseLoggingEnabled =
      ValueNotifier<bool>(Logger.root.level == verboseLoggingLevel);
  static const _verboseLoggingStorageId = 'verboseLogging';

  // TODO(https://github.com/flutter/devtools/issues/7860): Clean-up after
  // Inspector V2 has been released.
  InspectorPreferencesController get inspector => _inspector;
  final _inspector = InspectorPreferencesController();

  InspectorV2PreferencesController get inspectorV2 => _inspectorV2;
  final _inspectorV2 = InspectorV2PreferencesController();

  MemoryPreferencesController get memory => _memory;
  final _memory = MemoryPreferencesController();

  PerformancePreferencesController get performance => _performance;
  final _performance = PerformancePreferencesController();

  ExtensionsPreferencesController get devToolsExtensions => _extensions;
  final _extensions = ExtensionsPreferencesController();

  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    final darkModeValue = await storage.getValue('ui.darkMode');
    final useDarkMode = (darkModeValue == null && useDarkThemeAsDefault) ||
        darkModeValue == 'true';
    ga.impression(gac.devToolsMain, gac.startingTheme(darkMode: useDarkMode));
    toggleDarkModeTheme(useDarkMode);
    addAutoDisposeListener(darkModeTheme, () {
      storage.setValue('ui.darkMode', '${darkModeTheme.value}');
    });

    final vmDeveloperModeValue = await boolValueFromStorage(
      'ui.vmDeveloperMode',
      defaultsTo: false,
    );
    toggleVmDeveloperMode(vmDeveloperModeValue);
    addAutoDisposeListener(vmDeveloperModeEnabled, () {
      storage.setValue('ui.vmDeveloperMode', '${vmDeveloperModeEnabled.value}');
    });

    await _initVerboseLogging();

    await inspector.init();
    await memory.init();
    await performance.init();
    await devToolsExtensions.init();

    setGlobal(PreferencesController, this);
  }

  Future<void> _initVerboseLogging() async {
    final verboseLoggingEnabledValue = await boolValueFromStorage(
      _verboseLoggingStorageId,
      defaultsTo: false,
    );
    toggleVerboseLogging(verboseLoggingEnabledValue);
    addAutoDisposeListener(verboseLoggingEnabled, () {
      storage.setValue(
        'verboseLogging',
        verboseLoggingEnabled.value.toString(),
      );
    });
  }

  @override
  void dispose() {
    inspector.dispose();
    memory.dispose();
    performance.dispose();
    devToolsExtensions.dispose();
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
      if (enableVerboseLogging) {
        setDevToolsLoggingLevel(verboseLoggingLevel);
      } else {
        setDevToolsLoggingLevel(basicLoggingLevel);
      }
    }
  }
}

/// Retrieves a boolean value from the preferences stored in local storage.
///
/// If the value is not present in the stored preferences, this will default to
/// the value specified by [defaultsTo].
Future<bool> boolValueFromStorage(
  String storageKey, {
  required bool defaultsTo,
}) async {
  final value = await storage.getValue(storageKey);
  return defaultsTo ? value != 'false' : value == 'true';
}
