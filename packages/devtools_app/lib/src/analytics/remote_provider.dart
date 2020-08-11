// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'analytics.dart' as analytics;
import 'platform.dart' as platform;
import 'provider.dart';

class _RemoteAnalyticsProvider implements AnalyticsProvider {
  _RemoteAnalyticsProvider(this._isEnabled, this._isFirstRun);

  @override
  bool get isEnabled => _isEnabled;
  final bool _isEnabled;

  @override
  bool get isFirstRun => _isFirstRun;
  final bool _isFirstRun;

  @override
  bool get isGtagsEnabled => analytics.isGtagsEnabled();

  @override
  void setAllowAnalytics() => platform.setAllowAnalytics();

  @override
  void setDontAllowAnalytics() => platform.setDontAllowAnalytics();

  @override
  void setUpAnalytics() {
    analytics.initializeGA();
    platform.jsHookupListenerForGA();
  }
}

Future<AnalyticsProvider> get analyticsProvider async {
  if (_providerCompleter != null) return _providerCompleter.future;
  _providerCompleter = Completer<AnalyticsProvider>();
  var isEnabled = false;
  var isFirstRun = false;
  try {
    analytics.exposeGaDevToolsEnabledToJs();
    if (analytics.isGtagsReset()) {
      await analytics.resetDevToolsFile();
    }
    if (await analytics.isEnabled) {
      isEnabled = true;
      if (await analytics.isFirstRun) {
        isFirstRun = true;
      }
    }
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  _providerCompleter.complete(_RemoteAnalyticsProvider(isEnabled, isFirstRun));
  return _providerCompleter.future;
}

Completer<AnalyticsProvider> _providerCompleter;
