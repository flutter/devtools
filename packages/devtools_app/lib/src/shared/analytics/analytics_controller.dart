// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../development_helpers.dart';
import '../globals.dart';
import '../managers/dtd_manager_extensions.dart';

Future<AnalyticsController> get analyticsController async {
  if (_analyticsController != null) return _analyticsController!;

  var enabled = false;
  var shouldShowConsentMessage = false;
  try {
    enabled =
        debugSendAnalytics ||
        (kReleaseMode && await dtdManager.analyticsTelemetryEnabled());
    shouldShowConsentMessage =
        debugShowAnalyticsConsentMessage ||
        (kReleaseMode && await dtdManager.shouldShowAnalyticsConsentMessage());
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  return _analyticsController = AnalyticsController(
    enabled: enabled,
    shouldShowConsentMessage: shouldShowConsentMessage,
    consentMessage: await dtdManager.analyticsConsentMessage(),
  );
}

AnalyticsController? _analyticsController;

typedef AsyncAnalyticsCallback = FutureOr<void> Function();

class AnalyticsController {
  AnalyticsController({
    required bool enabled,
    required bool shouldShowConsentMessage,
    required this.consentMessage,
  }) : analyticsEnabled = ValueNotifier<bool>(enabled),
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
    } else {
      analyticsEnabled.value = false;
      hidePrompt();
      if (kReleaseMode) {
        await dtdManager.setAnalyticsTelemetry(false);
      }
    }
  }

  void setUpAnalytics() {
    if (_analyticsInitialized) return;
    assert(analyticsEnabled.value = true);
    _analyticsInitialized = true;
  }

  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}
