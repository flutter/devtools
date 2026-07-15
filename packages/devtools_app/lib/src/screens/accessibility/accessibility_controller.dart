// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';

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

  void _initListeners() {
    addAutoDisposeListener(brightness, _onBrightnessChanged);
    addAutoDisposeListener(textScale, _onTextScaleChanged);
    addAutoDisposeListener(boldText, _onBoldTextChanged);
    addAutoDisposeListener(screenReader, _onScreenReaderChanged);
    addAutoDisposeListener(highContrast, _onHighContrastChanged);
  }

  void _onBrightnessChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for brightness override.
    // e.g. using 'ext.flutter.brightnessOverride'.
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
