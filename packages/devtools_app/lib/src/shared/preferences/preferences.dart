// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
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
import '../feature_flags.dart';
import '../globals.dart';
import '../primitives/query_parameters.dart';
import '../utils/utils.dart';

part '_cpu_profiler_preferences.dart';
part '_extension_preferences.dart';
part '_inspector_preferences.dart';
part '_logging_preferences.dart';
part '_memory_preferences.dart';
part '_network_preferences.dart';
part '_performance_preferences.dart';

final _log = Logger('PreferencesController');

const _thirdPartyPathSegment = 'third_party';

/// DevTools preferences for experimental features.
enum _ExperimentPreferences {
  wasm;

  String get storageKey => '$storagePrefix.$name';

  static const storagePrefix = 'experiment';
}

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
enum _GeneralPreferences { verboseLogging }

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

  /// Whether DevTools should loaded with the dart2wasm + skwasm instead of
  /// dart2js + canvaskit
  final wasmEnabled = ValueNotifier<bool>(false);

  final verboseLoggingEnabled = ValueNotifier<bool>(
    Logger.root.level == verboseLoggingLevel,
  );

  CpuProfilerPreferencesController get cpuProfiler => _cpuProfiler;
  final _cpuProfiler = CpuProfilerPreferencesController();

  ExtensionsPreferencesController get devToolsExtensions => _extensions;
  final _extensions = ExtensionsPreferencesController();

  // TODO(https://github.com/flutter/devtools/issues/7860): Clean-up after
  // Inspector V2 has been released.
  InspectorPreferencesController get inspector => _inspector;
  final _inspector = InspectorPreferencesController();

  LoggingPreferencesController get logging => _logging;
  final _logging = LoggingPreferencesController();

  MemoryPreferencesController get memory => _memory;
  final _memory = MemoryPreferencesController();

  NetworkPreferencesController get network => _network;
  final _network = NetworkPreferencesController();

  PerformancePreferencesController get performance => _performance;
  final _performance = PerformancePreferencesController();

  @override
  Future<void> init() async {
    // Get the current values and listen for and write back changes.
    await _initDarkMode();
    await _initVmDeveloperMode();
    if (FeatureFlags.wasmOptInSetting) {
      await _initWasmEnabled();
    }
    await _initVerboseLogging();

    await cpuProfiler.init();
    await devToolsExtensions.init();
    await inspector.init();
    await logging.init();
    await memory.init();
    await network.init();
    await performance.init();

    setGlobal(PreferencesController, this);
  }

  Future<void> _initDarkMode() async {
    final darkModeValue = await storage.getValue(
      _UiPreferences.darkMode.storageKey,
    );
    final useDarkMode =
        (darkModeValue == null && useDarkThemeAsDefault) ||
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

  Future<void> _initWasmEnabled() async {
    wasmEnabled.value = kIsWasm;
    addAutoDisposeListener(wasmEnabled, () async {
      final enabled = wasmEnabled.value;
      _log.fine('preference update (wasmEnabled = $enabled)');

      await storage.setValue(
        _ExperimentPreferences.wasm.storageKey,
        '$enabled',
      );

      // Update the wasm mode query parameter if it does not match the value of
      // the setting.
      final wasmEnabledFromQueryParams = DevToolsQueryParams.load().useWasm;
      if (wasmEnabledFromQueryParams != enabled) {
        _log.fine(
          'Reloading DevTools for Wasm preference update (enabled = $enabled)',
        );
        updateQueryParameter(
          DevToolsQueryParams.wasmKey,
          enabled ? 'true' : null,
          reload: true,
        );
      }
    });

    final enabledFromStorage = await boolValueFromStorage(
      _ExperimentPreferences.wasm.storageKey,
      defaultsTo: false,
    );
    final queryParams = DevToolsQueryParams.load();
    final enabledFromQueryParams = queryParams.useWasm;

    if (enabledFromQueryParams && !kIsWasm) {
      // If we hit this case, we tried to load DevTools with WASM but we fell
      // back to JS. We know this because the flutter_bootstrap.js logic always
      // sets the 'wasm' query parameter to 'true' when attempting to load
      // DevTools with wasm. Remove the wasm query parameter and return early.
      updateQueryParameter(DevToolsQueryParams.wasmKey, null);
      ga.impression(gac.devToolsMain, gac.jsFallback);

      // Do not show the JS fallback notification when embedded in VS Code
      // because we do not expect the WASM build to load successfully by
      // default. This is because cross-origin-isolation is disabled by VS
      // Code. See https://github.com/microsoft/vscode/issues/186614.
      final embeddedInVsCode =
          queryParams.embedMode.embedded && queryParams.ide == 'VSCode';
      if (!embeddedInVsCode) {
        notificationService.push(
          'Something went wrong when trying to load DevTools with WebAssembly. '
          'Falling back to Javascript.',
        );
      }
      return;
    }

    // Whether DevTools was run using the `dt run` command, which runs DevTools
    // using `flutter run` and connects it to a locally running instance of the
    // DevTools server.
    final usingDebugDevToolsServer =
        (const String.fromEnvironment('debug_devtools_server')).isNotEmpty &&
        !kReleaseMode;
    final shouldEnableWasm =
        (enabledFromStorage || enabledFromQueryParams) &&
        kIsWeb &&
        // Wasm cannot be enabled if DevTools was built using `flutter run`.
        !usingDebugDevToolsServer;
    assert(kIsWasm == shouldEnableWasm);
    // This should be a no-op if the flutter_bootstrap.js logic set the
    // renderer properly, but we call this to be safe in case something went
    // wrong.
    toggleWasmEnabled(shouldEnableWasm);
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
    cpuProfiler.dispose();
    devToolsExtensions.dispose();
    inspector.dispose();
    logging.dispose();
    memory.dispose();
    network.dispose();
    performance.dispose();
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

  /// Change the value of the wasm mode setting.
  void toggleWasmEnabled(bool? enable) {
    if (enable != null) {
      wasmEnabled.value = enable;
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
