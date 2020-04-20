// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_model.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:devtools_testing/support/flutter/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;

  group('TimelineFlameChart', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
    });

    Future<void> pumpTimelineBody(
      WidgetTester tester,
      TimelineController controller,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        const TimelineScreenBody(),
        timeline: controller,
      ));
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds flame chart with data', windowSize,
        (WidgetTester tester) async {
      // Set a wide enough screen width that we do not run into overflow.
      final data = TimelineData()
        ..timelineEvents.addAll([goldenUiTimelineEvent])
        ..traceEvents.addAll(
            goldenUiTraceEvents.map((eventWrapper) => eventWrapper.event.json))
        ..time.start = goldenUiTimelineEvent.time.start
        ..time.end = goldenUiTimelineEvent.time.end;
      data.initializeEventGroups();
      final controllerWithData = TimelineController()
        ..allTraceEvents.addAll(goldenUiTraceEvents)
        ..data = data
        ..selectFrame(testFrame1);
      await pumpTimelineBody(tester, controllerWithData);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.recordingInstructionsKey), findsNothing);
    });

    testWidgetsWithWindowSize('builds flame chart with no data', windowSize,
        (WidgetTester tester) async {
      // Set a wide enough screen width that we do not run into overflow.
      await pumpTimelineBody(tester, TimelineController());
      expect(find.byType(TimelineFlameChart), findsNothing);
      expect(
        find.byKey(TimelineScreen.recordingInstructionsKey),
        findsOneWidget,
      );
    });
  });
}
