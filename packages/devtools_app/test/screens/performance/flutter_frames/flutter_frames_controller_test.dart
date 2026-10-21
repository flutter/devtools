// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../test_infra/test_data/performance/sample_performance_data.dart';

// TODO(kenz): add better test coverage for [FlutterFramesController].
void main() {
  late MockPerformanceController mockPerformanceController;
  late MockTimelineEventsController mockTimelineEventsController;
  late FlutterFramesController framesController;

  group('$FlutterFramesController', () {
    setUp(() {
      setGlobal(IdeTheme, IdeTheme());

      mockPerformanceController = createMockPerformanceControllerWithDefaults();
      mockTimelineEventsController = MockTimelineEventsController();
      when(
        mockPerformanceController.timelineEventsController,
      ).thenReturn(mockTimelineEventsController);
      framesController = FlutterFramesController(mockPerformanceController);
    });

    test('can toggle frame recording', () {
      expect(framesController.recordingFrames.value, isTrue);
      framesController.toggleRecordingFrames(false);
      expect(framesController.recordingFrames.value, isFalse);
      framesController.toggleRecordingFrames(true);
      expect(framesController.recordingFrames.value, isTrue);
    });

    test('can add frames', () {
      expect(framesController.flutterFrames.value, isEmpty);
      framesController.addFrame(testFrame1);
      expect(framesController.flutterFrames.value.length, equals(1));

      // Toggle recording value so that any added frames will not be added
      // directly, but will be marked as pending.
      framesController.toggleRecordingFrames(false);

      framesController.addFrame(testFrame2);
      expect(framesController.flutterFrames.value.length, equals(1));

      // Start recording again and verify that the pending frame has been added.
      framesController.toggleRecordingFrames(true);

      expect(framesController.flutterFrames.value.length, equals(2));
    });

    test('can toggle frame selection', () {
      bool timelineControllerHandlerCalled = false;
      when(
        // ignore: discarded_futures, by design
        mockTimelineEventsController.handleSelectedFrame(any),
      ).thenAnswer((_) {
        timelineControllerHandlerCalled = true;
        return Future.value();
      });

      expect(timelineControllerHandlerCalled, isFalse);

      // Select a frame.
      expect(framesController.selectedFrame.value, isNull);
      framesController.handleSelectedFrame(FlutterFrame2.frame);
      expect(framesController.selectedFrame.value, equals(FlutterFrame2.frame));
      // Verify the other feature controller handlers are called when a
      // frame is selected.
      expect(timelineControllerHandlerCalled, isTrue);

      // Unselect this frame.
      framesController.handleSelectedFrame(FlutterFrame2.frame);
      expect(framesController.selectedFrame.value, isNull);

      // Select a different frame.
      framesController.handleSelectedFrame(FlutterFrame4.frame);
      expect(framesController.selectedFrame.value, equals(FlutterFrame4.frame));
    });

    test('notifies listeners when events are assigned to selected frame', () {
      when(
        // ignore: discarded_futures, by design
        mockTimelineEventsController.handleSelectedFrame(any),
      ).thenAnswer((_) => Future.value());

      final frame = FlutterFrame.fromJson({
        'number': 3,
        'startTime': 40000,
        'elapsed': 20000,
        'build': 16000,
        'raster': 16000,
        'vsyncOverhead': 1000,
      });
      framesController.addFrame(frame);
      framesController.handleSelectedFrame(frame);
      expect(frame.frameAnalysis, isNull);

      var notifyCount = 0;
      framesController.selectedFrame.addListener(() => notifyCount++);

      // Assigning an event to the selected frame should notify listeners, even
      // though the selected frame instance has not changed.
      framesController.assignEventToFrame(frame.id, FlutterFrame2.uiEvent);
      expect(notifyCount, equals(1));
      expect(framesController.selectedFrame.value, equals(frame));
      expect(frame.frameAnalysis, isNotNull);

      // Assigning an event to a frame that is not selected should not notify.
      framesController.addFrame(testFrame2);
      framesController.assignEventToFrame(
        testFrame2.id,
        FlutterFrame2.rasterEvent,
      );
      expect(notifyCount, equals(1));
    });

    test('can setOfflineData', () async {
      // Ensure we are starting in an empty state.
      expect(framesController.flutterFrames.value, isEmpty);
      expect(framesController.selectedFrame.value, isNull);
      expect(
        framesController.displayRefreshRate.value,
        equals(defaultRefreshRate),
      );

      // TODO(kenz): add some timeline events for these frames to the offline
      // data and verify we correctly assign the events to their frames.
      final offlineData = OfflinePerformanceData(
        frames: [testFrame0, testFrame1],
        selectedFrame: testFrame0,
        displayRefreshRate: 120.0,
      );
      await framesController.setOfflineData(offlineData);

      expect(framesController.flutterFrames.value.length, equals(2));
      expect(framesController.selectedFrame.value, equals(testFrame0));
      expect(framesController.displayRefreshRate.value, equals(120.0));
    });

    test('can clearData', () {
      framesController.addFrame(testFrame0);
      framesController.addFrame(testFrame1);
      framesController.addFrame(testFrame2);
      framesController.addFrame(jankyFrame);
      framesController.handleSelectedFrame(testFrame0);
      expect(framesController.flutterFrames.value.length, 4);
      expect(framesController.selectedFrame.value, equals(testFrame0));
      framesController.clearData();
      expect(framesController.flutterFrames.value, isEmpty);
      expect(framesController.selectedFrame.value, isNull);
    });

    test('can clearData - partial', () {
      framesController.addFrame(testFrame0);
      framesController.addFrame(testFrame1);
      framesController.addFrame(testFrame2);
      framesController.addFrame(jankyFrame);
      framesController.handleSelectedFrame(testFrame0);
      expect(framesController.flutterFrames.value.length, 4);
      expect(framesController.selectedFrame.value, equals(testFrame0));
      framesController.clearData(partial: true);
      expect(framesController.flutterFrames.value.length, 2);
      expect(framesController.flutterFrames.value, isNot(contains(testFrame0)));
      expect(framesController.flutterFrames.value, isNot(contains(testFrame1)));
      expect(framesController.flutterFrames.value, contains(testFrame2));
      expect(framesController.flutterFrames.value, contains(jankyFrame));
      expect(framesController.selectedFrame.value, isNull);
    });
  });
}
