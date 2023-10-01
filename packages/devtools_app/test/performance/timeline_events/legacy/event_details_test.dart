// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/event_details.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/performance.dart';

void main() {
  const windowSize = Size(2000.0, 1000.0);

  group('EventDetails', () {
    Future<void> pumpEventDetails(
      TimelineEvent? selectedEvent,
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapSimple(EventDetails(selectedEvent)),
      );
      expect(find.byType(EventDetails), findsOneWidget);
    }

    setUp(() {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
    });

    testWidgetsWithWindowSize(
      'builds for UI event',
      windowSize,
      (WidgetTester tester) async {
        await pumpEventDetails(goldenUiTimelineEvent, tester);
        expect(find.byType(EventSummary), findsOneWidget);
        expect(find.text(EventDetails.noEventSelected), findsNothing);
        expect(find.text(EventDetails.instructions), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds for Raster event',
      windowSize,
      (WidgetTester tester) async {
        await pumpEventDetails(goldenRasterTimelineEvent, tester);
        expect(find.byType(EventSummary), findsOneWidget);
        expect(find.text(EventDetails.noEventSelected), findsNothing);
        expect(find.text(EventDetails.instructions), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds for ASYNC event',
      windowSize,
      (WidgetTester tester) async {
        await pumpEventDetails(asyncEventWithInstantChildren, tester);
        expect(find.byType(EventSummary), findsOneWidget);
        expect(find.text(EventDetails.noEventSelected), findsNothing);
        expect(find.text(EventDetails.instructions), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds for null event',
      windowSize,
      (WidgetTester tester) async {
        await pumpEventDetails(null, tester);
        expect(find.byType(EventSummary), findsNothing);
        expect(find.text(EventDetails.noEventSelected), findsOneWidget);
        expect(find.text(EventDetails.instructions), findsOneWidget);
      },
    );
  });

  // TODO(kenz): add golden images for these tests.
  group('EventSummary', () {
    EventSummary eventSummary;
    testWidgets('event with connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(asyncEventWithInstantChildren);
      await tester.pumpWidget(wrapSimple(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Time:  29.1 ms'), findsOneWidget);
      expect(find.text('Thread id:  19333'), findsOneWidget);
      expect(find.text('Process id:  94955'), findsOneWidget);
      expect(find.text('Category:  Embedder'), findsOneWidget);
      expect(find.text('Async id:  f1'), findsOneWidget);
      expect(find.text('Connected events'), findsOneWidget);
    });

    testWidgets('event without connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenUiTimelineEvent);
      await tester.pumpWidget(wrapSimple(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Time:  1.6 ms'), findsOneWidget);
      expect(find.text('Thread id:  1'), findsOneWidget);
      expect(find.text('Process id:  94955'), findsOneWidget);
      expect(find.text('Category:  Embedder'), findsOneWidget);
      expect(find.textContaining('Async id'), findsNothing);
      expect(find.text('Connected events'), findsNothing);
    });

    testWidgets('event with args', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenRasterTimelineEvent);
      await tester.pumpWidget(wrapSimple(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Time:  28.4 ms'), findsOneWidget);
      expect(find.text('Thread id:  2'), findsOneWidget);
      expect(find.text('Process id:  94955'), findsOneWidget);
      expect(find.text('Category:  Embedder'), findsOneWidget);
      expect(find.textContaining('Async id'), findsNothing);
      expect(find.text('Arguments'), findsOneWidget);
    });

    testWidgets('event without args', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenUiTimelineEvent);
      await tester.pumpWidget(wrapSimple(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Time:  1.6 ms'), findsOneWidget);
      expect(find.text('Thread id:  1'), findsOneWidget);
      expect(find.text('Process id:  94955'), findsOneWidget);
      expect(find.text('Category:  Embedder'), findsOneWidget);
      expect(find.textContaining('Async id'), findsNothing);
      expect(find.text('Arguments'), findsNothing);
    });
  });
}
