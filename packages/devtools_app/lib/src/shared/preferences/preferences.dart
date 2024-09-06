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
part '_memory_preferences.dart';
part '_logging_preferences.dart';
part '_performance_preferences.dart';

const _thirdPartyPathSegment = 'third_party';

/// DevTools preferences for UI-related settings.
enum _UiPreferences {
  darkMode,
  vmDeveloperMode;

  String get storageKey => '$storagePrefix.$name';

  static const storagePrefix = 'ui';
}

/// DevTools preferences for general settings.
///
/// These values are not stored in the DevTools storage file with a prefix.
enum _GeneralPreferences {
  verboseLogging,
}

/// A controller for global application preferences.
class PreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// Whether the user preference for DevTools theme is set to dark mode.
  ///
  /// To check whether DevTools is using a light or dark theme, other parts of
  /// the DevTools codebase should always check [isDarkThemeEnabled] instead of
  /// directly checking the value of this notifier. This is because
  /// [isDarkThemeEnabled] properly handles the case where DevTools is embedded
  /// inside of an IDE, and this notifier only tracks the value of the dark
  /// theme user preference.
  final darkModeEnabled = ValueNotifier<bool>(useDarkThemeAsDefault);

  final vmDeveloperModeEnabled = ValueNotifier<bool>(false);

  final verboseLoggingEnabled =
      ValueNotifier<bool>(Logger.root.level == verboseLoggingLevel);

  // TODO(https://github.com/flutter/devtools/issues/7860): Clean-up after
  // Inspector V2 has been released.
  InspectorPreferencesController get inspector => _inspector;
  final _inspector = InspectorPreferencesController();

  MemoryPreferencesController get memory => _memory;
  final _memory = MemoryPreferencesController();

  LoggingPreferencesController get logging => _logging;
  final _logging = LoggingPreferencesController();

  PerformancePreferencesController get performance => _performance;
  final _performance = PerformancePreferencesController();

  ExtensionsPreferencesController get devToolsExtensions => _extensions;
  final _extensions = ExtensionsPreferencesController();

  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    await _initDarkMode();
    await _initVmDeveloperMode();
    await _initVerboseLogging();

    await inspector.init();
    await memory.init();
    await logging.init();
    await performance.init();
    await devToolsExtensions.init();

    setGlobal(PreferencesController, this);
  }

  Future<void> _initDarkMode() async {
    final darkModeValue =
        await storage.getValue(_UiPreferences.darkMode.storageKey);
    final useDarkMode = (darkModeValue == null && useDarkThemeAsDefault) ||
        darkModeValue == 'true';
    ga.impression(gac.devToolsMain, gac.startingTheme(darkMode: useDarkMode));
    toggleDarkModeTheme(useDarkMode);
    addAutoDisposeListener(darkModeEnabled, () {
      storage.setValue(
        _UiPreferences.darkMode.storageKey,
        '${darkModeEnabled.value}',
      );
    });
  }

  Future<void> _initVmDeveloperMode() async {
    final vmDeveloperModeValue = await boolValueFromStorage(
      _UiPreferences.vmDeveloperMode.storageKey,
      defaultsTo: false,
    );
    toggleVmDeveloperMode(vmDeveloperModeValue);
    addAutoDisposeListener(vmDeveloperModeEnabled, () {
      storage.setValue(
        _UiPreferences.vmDeveloperMode.storageKey,
        '${vmDeveloperModeEnabled.value}',
      );
    });
  }

  Future<void> _initVerboseLogging() async {
    final verboseLoggingEnabledValue = await boolValueFromStorage(
      _GeneralPreferences.verboseLogging.name,
      defaultsTo: false,
    );
    toggleVerboseLogging(verboseLoggingEnabledValue);
    addAutoDisposeListener(verboseLoggingEnabled, () {
      storage.setValue(
        _GeneralPreferences.verboseLogging.name,
        verboseLoggingEnabled.value.toString(),
      );
    });
  }

  @override
  void dispose() {
    inspector.dispose();
    memory.dispose();
    logging.dispose();
    performance.dispose();
    devToolsExtensions.dispose();
    super.dispose();
  }

  /// Change the value of the dark mode setting.
  void toggleDarkModeTheme(bool? useDarkMode) {
    if (useDarkMode != null) {
      darkModeEnabled.value = useDarkMode;
    }
  }

  /// Change the value of the VM developer mode setting.
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
