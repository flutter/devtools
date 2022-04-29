// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// TODO(kenz): add tests for other widgets in common_widgets.dart

void main() {
  const instructionsKey = Key('instructions');
  const recordingStatusKey = Key('recordingStatus');
  const processingStatusKey = Key('processingStatus');
  const windowSize = Size(1000.0, 1000.0);

  group('Common widgets', () {
    setUp(() {
      setGlobal(ServiceConnectionManager, FakeServiceManager());
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgetsWithWindowSize('recordingInfo builds info for pause', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const RecordingInfo(
            instructionsKey: instructionsKey,
            recordingStatusKey: recordingStatusKey,
            processingStatusKey: processingStatusKey,
            recording: false,
            recordedObject: 'fake object',
            processing: false,
            isPause: true,
          ),
        ),
      );

      expect(find.byKey(instructionsKey), findsOneWidget);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsNothing);
      expect(find.text('Click the pause button '), findsOneWidget);
      expect(find.text('Click the stop button '), findsNothing);
    });

    testWidgetsWithWindowSize('recordingInfo builds info for stop', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const RecordingInfo(
            instructionsKey: instructionsKey,
            recordingStatusKey: recordingStatusKey,
            processingStatusKey: processingStatusKey,
            recording: false,
            recordedObject: 'fake object',
            processing: false,
          ),
        ),
      );

      expect(find.byKey(instructionsKey), findsOneWidget);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsNothing);
      expect(find.text('Click the stop button '), findsOneWidget);
      expect(find.text('Click the pause button '), findsNothing);
    });

    testWidgetsWithWindowSize(
        'recordingInfo builds recording status', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const RecordingInfo(
            instructionsKey: instructionsKey,
            recordingStatusKey: recordingStatusKey,
            processingStatusKey: processingStatusKey,
            recording: true,
            recordedObject: 'fake object',
            processing: false,
          ),
        ),
      );

      expect(find.byKey(instructionsKey), findsNothing);
      expect(find.byKey(recordingStatusKey), findsOneWidget);
      expect(find.byKey(processingStatusKey), findsNothing);
    });

    testWidgetsWithWindowSize(
        'recordingInfo builds processing status', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const RecordingInfo(
            instructionsKey: instructionsKey,
            recordingStatusKey: recordingStatusKey,
            processingStatusKey: processingStatusKey,
            recording: false,
            recordedObject: 'fake object',
            processing: true,
          ),
        ),
      );

      expect(find.byKey(instructionsKey), findsNothing);
      expect(find.byKey(recordingStatusKey), findsNothing);
      expect(find.byKey(processingStatusKey), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'processingInfo builds for progressValue', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const ProcessingInfo(
            progressValue: 0.0,
            processedObject: 'fake object',
          ),
        ),
      );

      final progressIndicatorFinder = find.byType(LinearProgressIndicator);
      LinearProgressIndicator progressIndicator =
          tester.widget(progressIndicatorFinder);

      expect(progressIndicator.value, equals(0.0));

      await tester.pumpWidget(
        wrap(
          const ProcessingInfo(
            progressValue: 0.5,
            processedObject: 'fake object',
          ),
        ),
      );
      progressIndicator = tester.widget(progressIndicatorFinder);
      expect(progressIndicator.value, equals(0.5));
    });
  });

  group('NotifierCheckbox', () {
    bool? findCheckboxValue() {
      final Checkbox checkboxWidget =
          find.byType(Checkbox).evaluate().first.widget as Checkbox;
      return checkboxWidget.value;
    }

    testWidgets('tap checkbox', (WidgetTester tester) async {
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: notifier)));
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
      await tester.tap(checkbox);
      await tester.pump();
      expect(notifier.value, isTrue);
      expect(findCheckboxValue(), isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
    });

    testWidgets('change notifier value', (WidgetTester tester) async {
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: notifier)));
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);

      notifier.value = true;
      await tester.pump();
      expect(notifier.value, isTrue);
      expect(findCheckboxValue(), isTrue);

      notifier.value = false;
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(notifier.value, isFalse);
      expect(findCheckboxValue(), isFalse);
    });

    testWidgets('change notifier', (WidgetTester tester) async {
      final falseNotifier = ValueNotifier<bool>(false);
      final trueNotifier = ValueNotifier<bool>(true);
      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: falseNotifier)));
      expect(findCheckboxValue(), isFalse);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: trueNotifier)));
      expect(findCheckboxValue(), isTrue);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: falseNotifier)));
      expect(findCheckboxValue(), isFalse);

      await tester.pumpWidget(wrap(NotifierCheckbox(notifier: trueNotifier)));
      expect(findCheckboxValue(), isTrue);

      // ensure we can modify the value of the notifier and changes are
      // reflected even though this is different than the initial notifier.
      trueNotifier.value = false;
      await tester.pump();
      expect(findCheckboxValue(), isFalse);

      trueNotifier.value = true;
      await tester.pump();
      expect(findCheckboxValue(), isTrue);
    });
  });

  group('AreaPaneHeader', () {
    const titleText = 'The title';
    const leftActionText = 'The Left Action';
    const centerActionText = 'The Center Action';
    const centerActionContainerKey = Key('scrollableCenterActionsContainer');
    const centerAction = Text(centerActionText);
    const leftAction = Text(leftActionText);

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgets(
        'does NOT show center actions if no left or center actions present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const AreaPaneHeader(
            title: Text(titleText),
          ),
        ),
      );
      expect(
        find.byKey(centerActionContainerKey),
        findsNothing,
      );
    });

    testWidgets('shows left actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const AreaPaneHeader(
            title: Text(titleText),
            leftActions: [leftAction],
          ),
        ),
      );
      expect(
        find.byKey(centerActionContainerKey),
        findsNothing,
      );
      expect(find.text(leftActionText), findsOneWidget);
    });

    testWidgets('shows center actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const AreaPaneHeader(
            title: Text(titleText),
            scrollableCenterActions: [centerAction],
          ),
        ),
      );
      expect(
        find.byKey(centerActionContainerKey),
        findsOneWidget,
      );
    });

    testWidgets('shows both left and center actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const AreaPaneHeader(
            title: Text(titleText),
            leftActions: [leftAction],
            scrollableCenterActions: [centerAction],
          ),
        ),
      );
      expect(
        find.byKey(centerActionContainerKey),
        findsOneWidget,
      );
      expect(find.text(leftActionText), findsOneWidget);
    });
  });
}
