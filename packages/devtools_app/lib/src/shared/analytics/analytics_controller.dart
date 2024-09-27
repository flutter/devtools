// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../development_helpers.dart';
import '../dtd_manager_extensions.dart';
import '../globals.dart';

import 'analytics.dart' as ga;

Future<AnalyticsController> get analyticsController async {
  if (_analyticsController != null) return _analyticsController!;

  // TODO(https://github.com/flutter/devtools/issues/7083): when the legacy
  // analytics are fully removed, this try-catch is unnecessary because we will
  // get these values directly from [dtdManater], like how the consentMessage
  // parameter is specified below.
  var enabled = false;
  var shouldShowConsentMessage = false;
  try {
    enabled = await ga.isAnalyticsEnabled();
    shouldShowConsentMessage = debugShowAnalyticsConsentMessage ||
        await ga.shouldShowAnalyticsConsentMessage();
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  return _analyticsController = AnalyticsController(
    enabled: enabled,
    shouldShowConsentMessage: shouldShowConsentMessage,
    consentMessage: await dtdManager.analyticsConsentMessage(),
    // TODO(https://github.com/flutter/devtools/issues/7083): remove these
    // when the legacy analytics are fully removed.
    legacyOnEnableAnalytics: ga.legacyOnEnableAnalytics,
    legacyOnDisableAnalytics: ga.legacyOnDisableAnalytics,
    legacyOnSetupAnalytics: ga.legacyOnSetupAnalytics,
  );
}

AnalyticsController? _analyticsController;

typedef AsyncAnalyticsCallback = FutureOr<void> Function();

class AnalyticsController {
  AnalyticsController({
    required bool enabled,
    required bool shouldShowConsentMessage,
    required this.consentMessage,
    this.legacyOnEnableAnalytics,
    this.legacyOnDisableAnalytics,
    this.legacyOnSetupAnalytics,
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

  /// Method to call to confirm with package:unified_analytics the user has
  /// seen the consent message.
  Future<void> markConsentMessageAsShown() async =>
      await dtdManager.analyticsClientShowedMessage();

  /// Consent message for package:unified_analytics to be shown on first run.
  final String consentMessage;

  // TODO(https://github.com/flutter/devtools/issues/7083): remove these
  // when the legacy analytics are fully removed.
  final AsyncAnalyticsCallback? legacyOnEnableAnalytics;
  final AsyncAnalyticsCallback? legacyOnDisableAnalytics;
  final VoidCallback? legacyOnSetupAnalytics;

  /// Sets whether google analytics are enabled.
  Future<void> toggleAnalyticsEnabled(bool? enable) async {
    if (enable == true) {
      analyticsEnabled.value = true;
      if (!_analyticsInitialized) {
        setUpAnalytics();
      }
      if (kReleaseMode) {
        await dtdManager.setAnalyticsTelemetry(true);
      }
      await legacyOnEnableAnalytics?.call();
    } else {
      analyticsEnabled.value = false;
      hidePrompt();
      if (kReleaseMode) {
        await dtdManager.setAnalyticsTelemetry(false);
      }
      await legacyOnDisableAnalytics?.call();
    }
  }

  void setUpAnalytics() {
    if (_analyticsInitialized) return;
    assert(analyticsEnabled.value = true);
    legacyOnSetupAnalytics?.call();
    _analyticsInitialized = true;
  }

  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}
