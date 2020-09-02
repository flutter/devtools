// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'provider.dart';

class _StubProvider implements AnalyticsProvider {
  @override
  bool get isEnabled => false;

  @override
  bool get shouldPrompt => false;

  @override
  bool get isGtagsEnabled => false;

  @override
  void setAllowAnalytics() {}

  @override
  void setDontAllowAnalytics() {}

  @override
  void setUpAnalytics() {}
}

Future<AnalyticsProvider> get analyticsProvider async => _provider;
AnalyticsProvider _provider = _StubProvider();
