// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract class AnalyticsProvider {
  bool get isGtagsEnabled;
  bool get shouldPrompt;
  bool get isEnabled;
  void setUpAnalytics();
  void setAllowAnalytics();
  void setDontAllowAnalytics();
}
