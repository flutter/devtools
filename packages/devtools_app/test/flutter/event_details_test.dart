// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/profiler/flutter/cpu_profiler.dart';
import 'package:devtools_app/src/timeline/flutter/event_details.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('EventDetails', () {
    EventDetails eventDetails;
    testWidgets('builds for UI event', (WidgetTester tester) async {
      eventDetails = EventDetails(goldenUiTimelineEvent);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsOneWidget);
      expect(find.byType(EventSummary), findsNothing);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgets('builds for GPU event', (WidgetTester tester) async {
      eventDetails = EventDetails(goldenGpuTimelineEvent);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgets('builds for ASYNC event', (WidgetTester tester) async {
      eventDetails = EventDetails(asyncEventWithInstantChildren);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgets('builds UI for null event', (WidgetTester tester) async {
      eventDetails = const EventDetails(null);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsNothing);
      expect(find.byType(EventSummary), findsNothing);
      expect(find.text(EventDetails.noEventSelected), findsOneWidget);
      expect(find.text(EventDetails.instructions), findsOneWidget);
    });
  });

  // TODO(kenz): add golden images for these tests.
  group('EventSummary', () {
    EventSummary eventSummary;
    testWidgets('event with connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(asyncEventWithInstantChildren);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Connected events'), findsOneWidget);
    });

    testWidgets('event without connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenUiTimelineEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Connected events'), findsNothing);
    });

    testWidgets('event with args', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenGpuTimelineEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Arguments'), findsOneWidget);
    });

    testWidgets('event without args', (WidgetTester tester) async {
      eventSummary = EventSummary(goldenUiTimelineEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Arguments'), findsNothing);
    });
  });
}
