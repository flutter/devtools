// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/test_data/performance.dart';

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
      when(mockPerformanceController.timelineEventsController)
          .thenReturn(mockTimelineEventsController);
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
      expect(
        framesController.flutterFrames.value.length,
        equals(1),
      );

      // Toggle recording value so that any added frames will not be added
      // directly, but will be marked as pending.
      framesController.toggleRecordingFrames(false);

      framesController.addFrame(testFrame2);
      expect(
        framesController.flutterFrames.value.length,
        equals(1),
      );

      // Start recording again and verify that the pending frame has been added.
      framesController.toggleRecordingFrames(true);

      expect(
        framesController.flutterFrames.value.length,
        equals(2),
      );
    });

    test('can toggle frame selection', () {
      final frame0 = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      final frame1UiEvent = goldenUiTimelineEvent.deepCopy();
      final frame1RasterEvent = goldenRasterTimelineEvent.deepCopy();
      final frame1 = testFrame1.shallowCopy()
        ..setEventFlow(frame1UiEvent)
        ..setEventFlow(frame1RasterEvent);

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
      framesController.handleSelectedFrame(frame0);
      expect(
        framesController.selectedFrame.value,
        equals(frame0),
      );
      // Verify the other feature controller handlers are called when a
      // frame is selected.
      expect(timelineControllerHandlerCalled, isTrue);

      // Unselect this frame.
      framesController.handleSelectedFrame(frame0);
      expect(
        framesController.selectedFrame.value,
        isNull,
      );

      // Select a different frame.
      framesController.handleSelectedFrame(frame1);
      expect(
        framesController.selectedFrame.value,
        equals(frame1),
      );
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
      expect(
        framesController.displayRefreshRate.value,
        equals(120.0),
      );
    });
  });
}
