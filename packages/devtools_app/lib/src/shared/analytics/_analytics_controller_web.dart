// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../server/server.dart' as server;
import 'analytics.dart' as ga;
import 'analytics_controller.dart';

Future<AnalyticsController> get devToolsAnalyticsController async {
  if (_controllerCompleter != null) return _controllerCompleter!.future;
  _controllerCompleter = Completer<AnalyticsController>();
  var enabled = false;
  var firstRun = false;
  try {
    if (await ga.isAnalyticsEnabled()) {
      enabled = true;
    }
    if (await server.isFirstRun()) {
      firstRun = true;
    }
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  _controllerCompleter!.complete(
    AnalyticsController(
      enabled: enabled,
      firstRun: firstRun,
      onEnableAnalytics: ga.enableAnalytics,
      onDisableAnalytics: ga.disableAnalytics,
      onSetupAnalytics: () {
        ga.initializeGA();
        ga.jsHookupListenerForGA();
      },
      consentMessage: await ga.getConsentMessage(),
    ),
  );
  return _controllerCompleter!.future;
}

Completer<AnalyticsController>? _controllerCompleter;
