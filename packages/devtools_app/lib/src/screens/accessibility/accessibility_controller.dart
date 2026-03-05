// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';

class AccessibilityController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  String get screenId => ScreenMetaData.accessibility.id;

  /// The root node of the semantics tree.
  ValueListenable<RemoteDiagnosticsNode?> get rootNode => _rootNode;
  final _rootNode = ValueNotifier<RemoteDiagnosticsNode?>(null);

  /// Whether the accessibility feature is enabled.
  ValueListenable<bool> get accessibilityEnabled => _accessibilityEnabled;
  final _accessibilityEnabled = ValueNotifier<bool>(false);

  ValueListenable<double> get textScaleFactor => _textScaleFactor;
  final _textScaleFactor = ValueNotifier<double>(1.0);

  ValueListenable<bool> get highContrastEnabled => _highContrastEnabled;
  final _highContrastEnabled = ValueNotifier<bool>(false);

  ValueListenable<bool> get autoAuditEnabled => _autoAuditEnabled;
  final _autoAuditEnabled = ValueNotifier<bool>(false);

  Future<void> toggleAccessibility(bool enable) async {
    _accessibilityEnabled.value = enable;
    if (enable) {
      // TODO(kenz): enable semantics and other accessibility features.
    } else {
      // TODO(kenz): disable semantics and other accessibility features.
    }
  }

  Future<void> setTextScaleFactor(double factor) async {
    _textScaleFactor.value = factor;
    // TODO(kenz): set text scale factor on device.
  }

  Future<void> toggleHighContrast(bool enable) async {
    _highContrastEnabled.value = enable;
    // TODO(kenz): set high contrast on device.
  }

  Future<void> toggleAutoAudit(bool enable) async {
    _autoAuditEnabled.value = enable;
    if (enable) {
      await runAudit();
    }
  }

  Future<void> runAudit() async {
    // TODO(kenz): run accessibility audit.
  }
}
