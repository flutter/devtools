// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'analytics_controller.dart';

FutureOr<AnalyticsController> get devToolsAnalyticsController => _controller;
AnalyticsController _controller = AnalyticsController(
  enabled: false,
  firstRun: false,
  consentMessage: 'fake message',
);
