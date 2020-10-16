// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../config_specific/server/server.dart' as server;
import 'analytics.dart' as analytics;
import 'provider.dart';

class _RemoteAnalyticsProvider implements AnalyticsProvider {
  _RemoteAnalyticsProvider(
    this._isEnabled,
    this._isFirstRun,
    this._isGtagsEnabled,
  );

  bool _isConfigured = false;

  @override
  bool get isEnabled => _isEnabled;
  final bool _isEnabled;

  @override
  bool get shouldPrompt => _isFirstRun && !_isConfigured;
  final bool _isFirstRun;

  @override
  bool get isGtagsEnabled => _isGtagsEnabled;
  final bool _isGtagsEnabled;

  @override
  void setAllowAnalytics() {
    _isConfigured = true;
    analytics.setAllowAnalytics();
  }

  @override
  void setDontAllowAnalytics() {
    _isConfigured = true;
    analytics.setDontAllowAnalytics();
  }

  @override
  void setUpAnalytics() {
    if (!_isGtagsEnabled) return;
    analytics.initializeGA();
    analytics.jsHookupListenerForGA();
  }
}

Future<AnalyticsProvider> get analyticsProvider async {
  if (_providerCompleter != null) return _providerCompleter.future;
  _providerCompleter = Completer<AnalyticsProvider>();
  var isEnabled = false;
  var isFirstRun = false;
  var isGtagsEnabled = false;
  try {
    analytics.exposeGaDevToolsEnabledToJs();
    if (analytics.isGtagsReset()) {
      await server.resetDevToolsFile();
    }
    if (await analytics.isAnalyticsEnabled()) {
      isEnabled = true;
    }
    if (await server.isFirstRun()) {
      isFirstRun = true;
    }
    isGtagsEnabled = analytics.isGtagsEnabled();
  } catch (_) {
    // Ignore issues if analytics could not be initialized.
  }
  _providerCompleter.complete(
      _RemoteAnalyticsProvider(isEnabled, isFirstRun, isGtagsEnabled));
  return _providerCompleter.future;
}

Completer<AnalyticsProvider> _providerCompleter;
