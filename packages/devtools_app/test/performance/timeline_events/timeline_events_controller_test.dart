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
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import '../../test_infra/test_data/performance.dart';

// TODO(kenz): add better test coverage for [TimelineEventsController].

void main() {
  final ServiceConnectionManager fakeServiceManager =
      FakeServiceConnectionManager(
    service: FakeServiceManager.createFakeService(
      timelineData: Timeline.parse(testTimelineJson)!,
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

      final performanceController =
          createMockPerformanceControllerWithDefaults();
      eventsController = TimelineEventsController(performanceController);
      final flutterFramesController = MockFlutterFramesController();
      when(performanceController.timelineEventsController)
          .thenReturn(eventsController);
      when(performanceController.flutterFramesController)
          .thenReturn(flutterFramesController);
      when(flutterFramesController.hasUnassignedFlutterFrame(any))
          .thenReturn(false);
    });

    // test('can setOfflineData', () async {
    //   // Ensure we are starting in an empty state.
    //   expect(eventsController.allTraceEvents, isEmpty);
    //   expect(eventsController.data!.timelineEvents, isEmpty);
    //   expect(eventsController.legacyController.processor.uiThreadId, isNull);
    //   expect(
    //     eventsController.legacyController.processor.rasterThreadId,
    //     isNull,
    //   );

    //   offlineController.enterOfflineMode(
    //     offlineApp: serviceConnection.serviceManager.connectedApp!,
    //   );
    //   final traceEvents = [...goldenUiTraceEvents, ...goldenRasterTraceEvents]
    //       .map((e) => e.json)
    //       .toList()
    //       .cast<Map<String, dynamic>>();
    //   // TODO(kenz): add some frames for these timeline events to the offline
    //   // data and verify we correctly assign the events to their frames.
    //   final offlineData = PerformanceData(traceEvents: traceEvents);
    //   await eventsController.setOfflineData(offlineData);

    //   expect(
    //     eventsController.allTraceEvents.length,
    //     equals(traceEvents.length),
    //   );
    //   expect(eventsController.data!.timelineEvents.length, equals(2));
    //   expect(
    //     eventsController.legacyController.processor.uiThreadId,
    //     equals(testUiThreadId),
    //   );
    //   expect(
    //     eventsController.legacyController.processor.rasterThreadId,
    //     equals(testRasterThreadId),
    //   );
    // });
  });
}
