// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'analytics.dart' as ga;
import 'analytics_controller.dart';

FutureOr<AnalyticsController> get devToolsAnalyticsController async {
  return AnalyticsController(
    enabled: false,
    firstRun: false,
    consentMessage: await ga.fetchAnalyticsConsentMessage(),
  );
}
