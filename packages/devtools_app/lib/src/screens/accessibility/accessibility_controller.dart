// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';

class AccessibilityController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  String get screenId => ScreenMetaData.accessibility.id;

  /// Whether the accessibility feature is enabled.
  ValueListenable<bool> get accessibilityEnabled => _accessibilityEnabled;
  final _accessibilityEnabled = ValueNotifier<bool>(false);

  ValueListenable<double> get textScaleFactor => _textScaleFactor;
  final _textScaleFactor = ValueNotifier<double>(1.0);

  ValueListenable<bool> get highContrastEnabled => _highContrastEnabled;
  final _highContrastEnabled = ValueNotifier<bool>(false);

  ValueListenable<bool> get autoAuditEnabled => _autoAuditEnabled;
  final _autoAuditEnabled = ValueNotifier<bool>(false);

  Future<void> setTextScaleFactor(double factor) async {
    _textScaleFactor.value = factor;
    // TODO(chunhtai): set text scale factor on device.
  }

  Future<void> toggleHighContrast(bool enable) async {
    _highContrastEnabled.value = enable;
    // TODO(chunhtai): set high contrast on device.
  }

  Future<void> toggleAutoAudit(bool enable) async {
    _autoAuditEnabled.value = enable;
    // TODO(chunhtai): auto run audit when enabled.
  }

  Future<void> runAudit() async {
    // TODO(chunhtai): run accessibility audit.
  }
}
