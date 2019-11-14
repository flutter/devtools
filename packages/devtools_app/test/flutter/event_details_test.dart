// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/profiler/flutter/cpu_profiler.dart';
import 'package:devtools_app/src/timeline/flutter/event_details.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('EventDetails', () {
    EventDetails eventDetails;
    testWidgets('builds for UI event', (WidgetTester tester) async {
      eventDetails = EventDetails(stubUiEvent);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsOneWidget);
      expect(find.byType(EventSummary), findsNothing);
    });

    testWidgets('builds for GPU event', (WidgetTester tester) async {
      eventDetails = EventDetails(stubGpuEvent);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
    });

    testWidgets('builds for ASYNC event', (WidgetTester tester) async {
      eventDetails = EventDetails(stubAsyncEvent);
      await tester.pumpWidget(wrap(eventDetails));
      expect(find.byType(EventDetails), findsOneWidget);
      expect(find.byType(CpuProfilerView), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
    });
  });

  // TODO(kenz): add golden images for these tests.
  group('EventSummary', () {
    EventSummary eventSummary;
    testWidgets('event with connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(stubAsyncEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Connected events'), findsOneWidget);
    });

    testWidgets('event without connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(stubUiEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Connected events'), findsNothing);
    });

    testWidgets('event with args', (WidgetTester tester) async {
      eventSummary = EventSummary(stubGpuEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Arguments'), findsOneWidget);
    });

    testWidgets('event without args', (WidgetTester tester) async {
      eventSummary = EventSummary(stubUiEvent);
      await tester.pumpWidget(wrap(eventSummary));
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text('Thread id'), findsOneWidget);
      expect(find.text('Process id'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Arguments'), findsNothing);
    });
  });
}
