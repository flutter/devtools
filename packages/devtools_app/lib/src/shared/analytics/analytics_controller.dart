// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dtd_manager_extensions.dart';
import '../globals.dart';
import '_analytics_controller_stub.dart'
    if (dart.library.js_interop) '_analytics_controller_web.dart';

// TODO(https://github.com/flutter/devtools/issues/7083): once the legacy
// analytics are removed, we will no longer need an analytics controller
// implementation for web and for desktop. With the unified analytics
// integration, all analytics requests will go through DTD, so there is no need
// for platform specific code.
Future<AnalyticsController> get analyticsController async =>
    await devToolsAnalyticsController;

typedef AsyncAnalyticsCallback = FutureOr<void> Function();

class AnalyticsController {
  AnalyticsController({
    required bool enabled,
    required bool shouldShowConsentMessage,
    required this.consentMessage,
    this.onEnableAnalytics,
    this.onDisableAnalytics,
    this.onSetupAnalytics,
  })  : analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(
          shouldShowConsentMessage && consentMessage.isNotEmpty,
        ) {
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

  /// Method to call to confirm with package:unified_analytics the user has
  /// seen the consent message.
  Future<void> markConsentMessageAsShown() async =>
      await dtdManager.analyticsClientShowedMessage();

  final VoidCallback? onSetupAnalytics;

  /// Consent message for package:unified_analytics to be shown on first run.
  final String consentMessage;

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
