// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../../test_infra/test_data/performance/sample_performance_data.dart';

// TODO(kenz): add better test coverage for [TimelineEventsController].

void main() {
  late MockPerformanceController performanceController;
  final fakeServiceManager = FakeServiceConnectionManager(
    service: FakeServiceManager.createFakeService(
      timelineData: perfettoVmTimeline,
    ),
  );

  group('$TimelineEventsController', () {
    late TimelineEventsController eventsController;

    setUp(() {
      when(
        fakeServiceManager.serviceManager.connectedApp!.isProfileBuild,
      ).thenAnswer((realInvocation) => Future.value(false));
      final initializedCompleter = Completer<bool>();
      initializedCompleter.complete(true);
      when(
        fakeServiceManager.serviceManager.connectedApp!.initialized,
      ).thenReturn(initializedCompleter);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineDataController, OfflineDataController());

      performanceController = createMockPerformanceControllerWithDefaults();
      eventsController = TimelineEventsController(performanceController);
      final flutterFramesController = MockFlutterFramesController();
      when(
        performanceController.timelineEventsController,
      ).thenReturn(eventsController);
      when(
        performanceController.flutterFramesController,
      ).thenReturn(flutterFramesController);
      when(
        flutterFramesController.hasUnassignedFlutterFrame(any),
      ).thenReturn(false);
    });

    test('can setOfflineData', () async {
      // Ensure we are starting in an empty state.
      expect(eventsController.fullPerfettoTrace, isEmpty);
      expect(eventsController.perfettoController.processor.uiTrackId, isNull);
      expect(
        eventsController.perfettoController.processor.rasterTrackId,
        isNull,
      );

      offlineDataController.startShowingOfflineData(
        offlineApp: serviceConnection.serviceManager.connectedApp!,
      );
      final offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
      when(
        performanceController.offlinePerformanceData,
      ).thenReturn(offlineData);
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

    group('can clearData', () {
      setUp(() async {
        // Set some data in the controller. It does not matter if it is connected
        // data or offline.
        offlineDataController.startShowingOfflineData(
          offlineApp: serviceConnection.serviceManager.connectedApp!,
        );
        final offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
        when(
          performanceController.offlinePerformanceData,
        ).thenReturn(offlineData);
        await eventsController.setOfflineData(offlineData);
      });

      test('full', () async {
        expect(eventsController.fullPerfettoTrace, isNotEmpty);
        await eventsController.clearData();
        expect(eventsController.fullPerfettoTrace, isEmpty);
      });

      test('partial', () async {
        expect(eventsController.fullPerfettoTrace, isNotEmpty);
        await eventsController.clearData();
        // This is empty because the original data only has one chunk.
        expect(eventsController.fullPerfettoTrace, isEmpty);
      });
    });

    test('init completes when the VM timeline is unavailable', () async {
      final originalService = fakeServiceManager.serviceManager.service;
      addTearDown(
        () => fakeServiceManager.serviceManager.service = originalService,
      );
      final service = MockVmServiceWrapper();
      fakeServiceManager.serviceManager.service = service;
      when(service.setVMTimelineFlags(any)).thenAnswer((_) async => Success());
      when(
        service.getVMTimelineMicros(),
      ).thenAnswer((_) async => Timestamp(timestamp: 0));
      // The VM rejects timeline requests while the systrace recorder is used.
      when(
        service.getPerfettoVMTimeline(
          timeOriginMicros: anyNamed('timeOriginMicros'),
          timeExtentMicros: anyNamed('timeExtentMicros'),
        ),
      ).thenAnswer(
        (_) async => throw RPCError(
          'getPerfettoVMTimeline',
          RPCErrorKind.kInvalidTimelineRequest.code,
        ),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(NotificationService, NotificationService());
      addTearDown(eventsController.dispose);

      await eventsController.init();
      await eventsController.forceRefresh();

      expect(eventsController.status.value, EventsControllerStatus.ready);
      verify(service.getVMTimelineMicros()).called(1);
      expect(
        notificationService.activeMessages.single.text,
        contains('systrace'),
      );
    });
  });
}
