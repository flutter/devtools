// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '_analytics_controller_stub.dart'
    if (dart.library.js_interop) '_analytics_controller_web.dart';

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
    this.consentMessage,
  })  : analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled) {
    if (_shouldPrompt.value) {
      unawaited(toggleAnalyticsEnabled(true));
    }
    if (analyticsEnabled.value) {
      setUpAnalytics();
    }
  }

  final ValueNotifier<bool> analyticsEnabled;

  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  bool get analyticsInitialized => _analyticsInitialized;
  bool _analyticsInitialized = false;

  final AsyncAnalyticsCallback? onEnableAnalytics;

  final AsyncAnalyticsCallback? onDisableAnalytics;

  final VoidCallback? onSetupAnalytics;

  final String? consentMessage;

  Future<void> toggleAnalyticsEnabled(bool? enable) async {
    if (enable == true) {
      analyticsEnabled.value = true;
      if (!_analyticsInitialized) {
        setUpAnalytics();
      }
      if (onEnableAnalytics != null) {
        await onEnableAnalytics!();
      }
    } else {
      analyticsEnabled.value = false;
      hidePrompt();
      if (onDisableAnalytics != null) {
        await onDisableAnalytics!();
      }
    }
  }

  /// Returns the consent message for package:unified_analytics from
  /// the server. After showing message, the [consentMessageShown] method
  /// should be called to onboard the user to analytics collection.
  String? getConsentMessage() => consentMessage;

  void setUpAnalytics() {
    if (_analyticsInitialized) return;
    assert(analyticsEnabled.value = true);
    if (onSetupAnalytics != null) {
      onSetupAnalytics!();
    }
    _analyticsInitialized = true;
  }

  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}
