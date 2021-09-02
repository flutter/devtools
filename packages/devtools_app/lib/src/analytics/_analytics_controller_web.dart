// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config_specific/server/server.dart' as server;
// It is okay to import the web analytics here because this file is a web
// specific implementation itself.
import '_analytics_web.dart' as ga;
import 'analytics_common.dart';

class AnalyticsController implements AnalyticsControllerBase {
  AnalyticsController(
    bool enabled,
    bool firstRun,
  )   : _analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled) {
    if (_shouldPrompt.value) {
      toggleAnalyticsEnabled(true);
    }
    if (_analyticsEnabled.value) {
      setUpAnalytics();
    }
  }

  @override
  ValueListenable<bool> get analyticsEnabled => _analyticsEnabled;
  final ValueNotifier<bool> _analyticsEnabled;

  @override
  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  @override
  bool get analyticsInitialized => _analyticsInitialized;
  bool _analyticsInitialized = false;

  @override
  Future<void> toggleAnalyticsEnabled(bool enable) async {
    if (enable) {
      _analyticsEnabled.value = true;
      if (!_analyticsInitialized) {
        setUpAnalytics();
      }
      await ga.enableAnalytics();
    } else {
      _analyticsEnabled.value = false;
      hidePrompt();
      await ga.disableAnalytics();
    }
  }

  @override
  void setUpAnalytics() {
    if (_analyticsInitialized) return;
    assert(_analyticsEnabled.value = true);
    ga.initializeGA();
    ga.jsHookupListenerForGA();
    _analyticsInitialized = true;
  }

  @override
  void hidePrompt() {
    _shouldPrompt.value = false;
  }
}

Future<AnalyticsController> get analyticsController async {
  if (_controllerCompleter != null) return _controllerCompleter.future;
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
  _controllerCompleter.complete(AnalyticsController(enabled, firstRun));
  return _controllerCompleter.future;
}

Completer<AnalyticsControllerBase> _controllerCompleter;
