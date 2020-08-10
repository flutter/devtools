// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'provider.dart';

class _StubProvider implements AnalyticsProvider {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> get isEnabled async => false;

  @override
  Future<bool> get isFirstRun async => false;

  @override
  bool get isGtagsEnabled => false;

  @override
  void setAllowAnalytics() {}

  @override
  void setDontAllowAnalytics() {}

  @override
  void setUpAnalytics() {}
}

AnalyticsProvider _provider = _StubProvider();
AnalyticsProvider get provider => _provider;
