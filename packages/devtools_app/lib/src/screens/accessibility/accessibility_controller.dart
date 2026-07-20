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
  system('System Default', 'system'),
  light('Light Mode', 'Brightness.light'),
  dark('Dark Mode', 'Brightness.dark');

  const BrightnessOverride(this.display, this.value);

  /// The user-facing display label for this override option.
  final String display;

  /// The raw value associated with this override option sent to or received
  /// from the VM service extension.
  final String value;
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

    void updateFromDeviceState(ServiceExtensionState state) {
      final newBrightness = !state.enabled || state.value == null
          ? BrightnessOverride.system
          : BrightnessOverride.values.firstWhere(
              (b) => b.value == state.value,
              orElse: () => BrightnessOverride.system,
            );
      brightness.value = newBrightness;
    }

    updateFromDeviceState(state.value);
    addAutoDisposeListener(state, () => updateFromDeviceState(state.value));
  }

  void _onBrightnessChanged() {
    final value = brightness.value;
    unawaited(
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extensions.brightnessMode.extension,
            enabled: value != BrightnessOverride.system,
            value: value.value,
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
