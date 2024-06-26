// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../flutter_frames/flutter_frame_model.dart';

// TODO(kenz): merge this control with the Rebuild Stats model class so that
// this feature conforms to the patterns of other Performance page features.
// This is just a temporary placeholder to ensure that we do not switch off of
// the Rebuild Stats tab when frame selections occur.
class RebuildStatsController extends PerformanceFeatureController {
  RebuildStatsController(super.performanceController);

  @override
  FutureOr<void> clearData() {}

  @override
  void handleSelectedFrame(FlutterFrame frame) {}

  @override
  Future<void> init() async {}

  @override
  void onBecomingActive() {}

  @override
  Future<void> setOfflineData(OfflinePerformanceData offlineData) async {}
}
