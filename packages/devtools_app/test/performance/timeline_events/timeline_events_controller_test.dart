// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

// TODO(kenz): add better test coverage for [TimelineEventsController].

void main() {
  late MockPerformanceController performanceController;
  final ServiceConnectionManager fakeServiceManager =
      FakeServiceConnectionManager(
    service: FakeServiceManager.createFakeService(
      timelineData: perfettoVmTimeline,
    ),
  );

  group('$TimelineEventsController', () {
    late TimelineEventsController eventsController;

    setUp(() {
      when(fakeServiceManager.serviceManager.connectedApp!.isProfileBuild)
          .thenAnswer((realInvocation) => Future.value(false));
      final initializedCompleter = Completer<bool>();
      initializedCompleter.complete(true);
      when(fakeServiceManager.serviceManager.connectedApp!.initialized)
          .thenReturn(initializedCompleter);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineModeController, OfflineModeController());

      performanceController = createMockPerformanceControllerWithDefaults();
      eventsController = TimelineEventsController(performanceController);
      final flutterFramesController = MockFlutterFramesController();
      when(performanceController.timelineEventsController)
          .thenReturn(eventsController);
      when(performanceController.flutterFramesController)
          .thenReturn(flutterFramesController);
      when(flutterFramesController.hasUnassignedFlutterFrame(any))
          .thenReturn(false);
    });

    test('can setOfflineData', () async {
      // Ensure we are starting in an empty state.
      expect(eventsController.fullPerfettoTrace, isEmpty);
      expect(eventsController.perfettoController.processor.uiTrackId, isNull);
      expect(
        eventsController.perfettoController.processor.rasterTrackId,
        isNull,
      );

      offlineController.enterOfflineMode(
        offlineApp: serviceConnection.serviceManager.connectedApp!,
      );
      final offlineData = OfflinePerformanceData.parse(rawPerformanceData);
      when(performanceController.offlinePerformanceData)
          .thenReturn(offlineData);
      await eventsController.setOfflineData(offlineData);

      expect(eventsController.fullPerfettoTrace, isNotEmpty);
      expect(
        eventsController.perfettoController.processor.uiTrackId,
        equals(testUiTrackId),
      );
      expect(
        eventsController.perfettoController.processor.rasterTrackId,
        equals(testRasterTrackId),
      );
    });
  });
}
