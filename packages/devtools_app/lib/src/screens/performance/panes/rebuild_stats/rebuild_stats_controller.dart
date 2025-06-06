// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
  void clearData({bool partial = false}) {}

  @override
  void handleSelectedFrame(FlutterFrame frame) {}

  @override
  Future<void> init() async {}

  @override
  void onBecomingActive() {}

  @override
  Future<void> setOfflineData(OfflinePerformanceData offlineData) async {}
}
