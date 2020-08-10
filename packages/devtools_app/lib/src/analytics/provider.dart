// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract class AnalyticsProvider {
  Future<void> initialize();
  bool get isGtagsEnabled;
  Future<bool> get isFirstRun;
  Future<bool> get isEnabled;
  void setUpAnalytics();
  void setAllowAnalytics();
  void setDontAllowAnalytics();
}
