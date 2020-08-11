// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'analytics.dart' as analytics;
import 'platform.dart' as platform;
import 'provider.dart';

class _RemoteAnalyticsProvider implements AnalyticsProvider {
  @override
  Future<void> initialize() async {
    analytics.exposeGaDevToolsEnabledToJs();
    if (analytics.isGtagsReset()) {
      await analytics.resetDevToolsFile();
    }
  }

  @override
  Future<bool> get isEnabled async => _isEnabled ??= await analytics.isEnabled;
  bool _isEnabled;

  @override
  Future<bool> get isFirstRun async =>
      _isFirstRun ??= await analytics.isFirstRun;
  bool _isFirstRun;

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

AnalyticsProvider get provider => _provider;
AnalyticsProvider _provider = _RemoteAnalyticsProvider();
