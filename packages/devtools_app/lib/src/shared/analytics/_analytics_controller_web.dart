// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../dtd_manager_extensions.dart';
import '../globals.dart';
import 'analytics.dart' as ga;
import 'analytics_controller.dart';

Future<AnalyticsController> get devToolsAnalyticsController async {
  if (_controllerCompleter != null) return _controllerCompleter!.future;
  _controllerCompleter = Completer<AnalyticsController>();
  var enabled = false;
  var shouldShowConsentMessage = false;
  try {
    if (await ga.isAnalyticsEnabled()) {
      enabled = true;
    }
    if (await ga.shouldShowAnalyticsConsentMessage()) {
      shouldShowConsentMessage = true;
    }
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  _controllerCompleter!.complete(
    AnalyticsController(
      enabled: enabled,
      shouldShowConsentMessage: shouldShowConsentMessage,
      onEnableAnalytics: () => ga.setAnalyticsEnabled(true),
      onDisableAnalytics: () => ga.setAnalyticsEnabled(false),
      onSetupAnalytics: () {
        ga.initializeGA();
        ga.jsHookupListenerForGA();
      },
      consentMessage: await dtdManager.analyticsConsentMessage(),
    ),
  );
  return _controllerCompleter!.future;
}

Completer<AnalyticsController>? _controllerCompleter;
