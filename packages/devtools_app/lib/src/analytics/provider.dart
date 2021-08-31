// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

class AnalyticsProvider {
  final ValueListenable<bool> analyticsEnabled = ValueNotifier<bool>(false);
  final ValueListenable<bool> shouldPrompt = ValueNotifier<bool>(false);
  void enableAnalytics() {}
  void disableAnalytics() {}
  void setUpAnalytics() {}
}

Future<AnalyticsProvider> get analyticsProvider async => _provider;
AnalyticsProvider _provider = AnalyticsProvider();
