// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../service/service_extensions.dart' as extensions;
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';

/// Modes for brightness override in the accessibility controls.
enum BrightnessOverride {
  system('System Default'),
  light('Light Mode'),
  dark('Dark Mode');

  const BrightnessOverride(this.display);

  final String display;
}

/// Controller for the Accessibility screen.
class AccessibilityController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  AccessibilityController() {
    _initListeners();
  }

  @override
  void init() {
    super.init();
    _initServiceExtensionStates();
  }

  void _initListeners() {
    addAutoDisposeListener(brightness, _onBrightnessChanged);
    addAutoDisposeListener(textScale, _onTextScaleChanged);
    addAutoDisposeListener(boldText, _onBoldTextChanged);
    addAutoDisposeListener(screenReader, _onScreenReaderChanged);
    addAutoDisposeListener(highContrast, _onHighContrastChanged);
  }

  void _initServiceExtensionStates() {
    final state = serviceConnection.serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensions.brightnessMode.extension);

    void updateFromDeviceState(ServiceExtensionState s) {
      final newBrightness = !s.enabled || s.value == null
          ? BrightnessOverride.system
          : switch (s.value) {
              'Brightness.light' => BrightnessOverride.light,
              'Brightness.dark' => BrightnessOverride.dark,
              _ => BrightnessOverride.system,
            };
      if (brightness.value != newBrightness) {
        brightness.value = newBrightness;
      }
    }

    updateFromDeviceState(state.value);
    addAutoDisposeListener(
      state,
      () => updateFromDeviceState(state.value),
    );
  }

  void _onBrightnessChanged() {
    final value = brightness.value;
    // Values expected by Flutter framework's 'ext.flutter.brightnessOverride':
    // - 'Brightness.light': forces light mode
    // - 'Brightness.dark': forces dark mode
    // - '': any value other than 'Brightness.light' or 'Brightness.dark' clears
    //   the override and resets to system default.
    final paramValue = switch (value) {
      BrightnessOverride.light => 'Brightness.light',
      BrightnessOverride.dark => 'Brightness.dark',
      BrightnessOverride.system => '',
    };
    unawaited(
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
        extensions.brightnessMode.extension,
        enabled: value != BrightnessOverride.system,
        value: paramValue,
      ),
    );
  }

  void _onTextScaleChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for text scale override.
  }

  void _onBoldTextChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for bold text override.
  }

  void _onScreenReaderChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for screen reader / semantics debugger.
    // e.g. using 'ext.flutter.showSemanticsDebugger'.
  }

  void _onHighContrastChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for high contrast override.
  }

  @override
  final screenId = ScreenMetaData.accessibility.id;

  // --- Accessibility Overrides State ---
  final brightness = ValueNotifier<BrightnessOverride>(
    BrightnessOverride.system,
  );
  final textScale = ValueNotifier<double>(1.0);
  final boldText = ValueNotifier<bool>(false);
  final screenReader = ValueNotifier<bool>(false);
  final highContrast = ValueNotifier<bool>(false);

  @override
  void dispose() {
    brightness.dispose();
    textScale.dispose();
    boldText.dispose();
    screenReader.dispose();
    highContrast.dispose();
    super.dispose();
  }
}
