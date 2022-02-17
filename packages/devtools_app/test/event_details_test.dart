// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/performance/event_details.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_model.dart';
import 'package:devtools_app/src/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/vm_flags.dart' as vm_flags;
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'test_data/performance_test_data.dart';

void main() {
  const windowSize = Size(2000.0, 1000.0);

  group('EventDetails', () {
    EventDetails eventDetails;

    Future<void> pumpEventDetails(
      TimelineEvent selectedEvent,
      WidgetTester tester,
    ) async {
      eventDetails = EventDetails(selectedEvent);
      await tester.pumpWidget(wrapWithControllers(
        eventDetails,
        performance: PerformanceController(),
      ));
      expect(find.byType(EventDetails), findsOneWidget);
    }

    setUp(() {
      final fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      when(serviceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    });

    testWidgetsWithWindowSize('builds for UI event', windowSize,
        (WidgetTester tester) async {
      await pumpEventDetails(goldenUiTimelineEvent, tester);
      expect(find.byType(CpuProfiler), findsOneWidget);
      expect(find.byType(CpuProfilerDisabled), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgetsWithWindowSize('builds for Raster event', windowSize,
        (WidgetTester tester) async {
      await pumpEventDetails(goldenRasterTimelineEvent, tester);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(CpuProfilerDisabled), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgetsWithWindowSize('builds for ASYNC event', windowSize,
        (WidgetTester tester) async {
      await pumpEventDetails(asyncEventWithInstantChildren, tester);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(CpuProfilerDisabled), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);
    });

    testWidgetsWithWindowSize('builds for null event', windowSize,
        (WidgetTester tester) async {
      await pumpEventDetails(null, tester);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(CpuProfilerDisabled), findsNothing);
      expect(find.byType(EventSummary), findsNothing);
      expect(find.text(EventDetails.noEventSelected), findsOneWidget);
      expect(find.text(EventDetails.instructions), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds for disabled profiler', windowSize,
        (WidgetTester tester) async {
      await serviceManager.service.setFlag(vm_flags.profiler, 'false');
      await pumpEventDetails(goldenUiTimelineEvent, tester);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(CpuProfilerDisabled), findsOneWidget);
      expect(find.byType(EventSummary), findsNothing);
      expect(find.text(EventDetails.noEventSelected), findsNothing);
      expect(find.text(EventDetails.instructions), findsNothing);

      await tester.tap(find.text('Enable profiler'));
      await tester.pumpAndSettle();

      expect(find.byType(CpuProfiler), findsOneWidget);
      expect(find.byType(CpuProfilerDisabled), findsNothing);
      expect(find.byType(EventSummary), findsOneWidget);
    });
  });

  // TODO(kenz): add golden images for these tests.
  group('EventSummary', () {
    EventSummary eventSummary;
    testWidgets('event with connected events', (WidgetTester tester) async {
      eventSummary = EventSummary(asyncEventWithInstantChildren);
      await tester.pumpWidget(wrap(eventSummary));
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
      await tester.pumpWidget(wrap(eventSummary));
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
      await tester.pumpWidget(wrap(eventSummary));
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
      await tester.pumpWidget(wrap(eventSummary));
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
