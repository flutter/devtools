// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

// TODO(kenz): add tests for other widgets in common_widgets.dart

void main() {
  const instructionsKey = Key('instructions');
  const recordingStatusKey = Key('recordingStatus');
  const processingStatusKey = Key('processingStatus');
  const windowSize = Size(1000.0, 1000.0);

  group('Common widgets', () {
    testWidgetsWithWindowSize('recordingInfo builds info for pause', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const RecordingInfo(
        instructionsKey: instructionsKey,
        recordingStatusKey: recordingStatusKey,
        processingStatusKey: processingStatusKey,
        recording: false,
        recordedObject: 'fake object',
        processing: false,
        isPause: true,
      )));

      expect(find.byKey(instructionsKey), findsOneWidget);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsNothing);
      expect(find.text('Click the pause button '), findsOneWidget);
      expect(find.text('Click the stop button '), findsNothing);
    });

    testWidgetsWithWindowSize('recordingInfo builds info for stop', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const RecordingInfo(
        instructionsKey: instructionsKey,
        recordingStatusKey: recordingStatusKey,
        processingStatusKey: processingStatusKey,
        recording: false,
        recordedObject: 'fake object',
        processing: false,
      )));

      expect(find.byKey(instructionsKey), findsOneWidget);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsNothing);
      expect(find.text('Click the stop button '), findsOneWidget);
      expect(find.text('Click the pause button '), findsNothing);
    });

    testWidgetsWithWindowSize(
        'recordingInfo builds recording status', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const RecordingInfo(
        instructionsKey: instructionsKey,
        recordingStatusKey: recordingStatusKey,
        processingStatusKey: processingStatusKey,
        recording: true,
        recordedObject: 'fake object',
        processing: false,
      )));

      expect(find.byKey(instructionsKey), findsNothing);
      expect(find.byKey(recordingStatusKey), findsOneWidget);
      expect(find.byKey(processingStatusKey), findsNothing);
    });

    testWidgetsWithWindowSize(
        'recordingInfo builds processing status', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const RecordingInfo(
        instructionsKey: instructionsKey,
        recordingStatusKey: recordingStatusKey,
        processingStatusKey: processingStatusKey,
        recording: false,
        recordedObject: 'fake object',
        processing: true,
      )));

      expect(find.byKey(instructionsKey), findsNothing);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'processingInfo builds for progressValue', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const ProcessingInfo(
        progressValue: 0.0,
        processedObject: 'fake object',
      )));

      final progressIndicatorFinder = find.byType(LinearProgressIndicator);
      LinearProgressIndicator progressIndicator =
          tester.widget(progressIndicatorFinder);

      expect(progressIndicator.value, equals(0.0));

      await tester.pumpWidget(wrap(const ProcessingInfo(
        progressValue: 0.5,
        processedObject: 'fake object',
      )));
      progressIndicator = tester.widget(progressIndicatorFinder);
      expect(progressIndicator.value, equals(0.5));
    });
  });
}
