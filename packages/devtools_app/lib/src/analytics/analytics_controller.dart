// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '_analytics_controller_stub.dart'
    if (dart.library.html) '_analytics_controller_web.dart';

Future<AnalyticsController> get analyticsController async =>
    await devToolsAnalyticsController;

typedef AsyncAnalyticsCallback = FutureOr<void> Function();

class AnalyticsController {
  AnalyticsController({
    required bool enabled,
    required bool firstRun,
    this.onEnableAnalytics,
    this.onDisableAnalytics,
    this.onSetupAnalytics,
  })  : _analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled) {
    if (_shouldPrompt.value) {
      toggleAnalyticsEnabled(true);
    }
    if (_analyticsEnabled.value) {
      setUpAnalytics();
    }
  }

  ValueListenable<bool> get analyticsEnabled => _analyticsEnabled;
  final ValueNotifier<bool> _analyticsEnabled;

  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  bool get analyticsInitialized => _analyticsInitialized;
  bool _analyticsInitialized = false;

  final AsyncAnalyticsCallback? onEnableAnalytics;

  final AsyncAnalyticsCallback? onDisableAnalytics;

  final VoidCallback? onSetupAnalytics;

  Future<void> toggleAnalyticsEnabled(bool enable) async {
    if (enable) {
      _analyticsEnabled.value = true;
      if (!_analyticsInitialized) {
        setUpAnalytics();
      }
      if (onEnableAnalytics != null) {
        await onEnableAnalytics!();
      }
    } else {
      _analyticsEnabled.value = false;
      hidePrompt();
      if (onDisableAnalytics != null) {
        await onDisableAnalytics!();
      }
    }
  }

  void setUpAnalytics() {
    if (_analyticsInitialized) return;
    assert(_analyticsEnabled.value = true);
    if (onSetupAnalytics != null) {
      onSetupAnalytics!();
    }
    _analyticsInitialized = true;
  }

  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}
