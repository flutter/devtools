// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config_specific/server/server.dart' as server;
import 'analytics.dart' as analytics;
import 'provider.dart';

class _RemoteAnalyticsProvider implements AnalyticsProvider {
  _RemoteAnalyticsProvider(
    bool enabled,
    bool firstRun,
  )   : _analyticsEnabled = ValueNotifier<bool>(enabled),
        _shouldPrompt = ValueNotifier<bool>(firstRun && !enabled);

  @override
  ValueListenable<bool> get analyticsEnabled => _analyticsEnabled;
  final ValueNotifier<bool> _analyticsEnabled;

  @override
  ValueListenable<bool> get shouldPrompt => _shouldPrompt;
  final ValueNotifier<bool> _shouldPrompt;

  bool analyticsInitialized = false;

  @override
  Future<void> enableAnalytics() async {
    _analyticsEnabled.value = await analytics.enableAnalytics();
  }

  @override
  Future<void> disableAnalytics() async {
    _analyticsEnabled.value = await analytics.disableAnalytics();
    _shouldPrompt.value = false;
  }

  @override
  void setUpAnalytics() {
    if (analyticsInitialized) return;
    analytics.initializeGA();
    analytics.jsHookupListenerForGA();
    analyticsInitialized = true;
  }
}

Future<AnalyticsProvider> get analyticsProvider async {
  if (_providerCompleter != null) return _providerCompleter.future;
  _providerCompleter = Completer<AnalyticsProvider>();
  var enabled = false;
  var firstRun = false;
  try {
    if (await analytics.isAnalyticsEnabled()) {
      enabled = true;
    }
    if (await server.isFirstRun()) {
      firstRun = true;
    }
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  _providerCompleter.complete(_RemoteAnalyticsProvider(enabled, firstRun));
  return _providerCompleter.future;
}

Completer<AnalyticsProvider> _providerCompleter;
