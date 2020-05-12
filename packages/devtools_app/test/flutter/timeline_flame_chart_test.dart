// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:devtools_testing/support/flutter/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;
  group('TimelineFlameChart', () {
    void _setupForTimeline(Map<String, dynamic> timelineJson) {
      fakeServiceManager = FakeServiceManager(
        useFakeService: true,
        timelineData: vm_service.Timeline.parse(timelineJson),
      );
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
    }

    setUp(() async {
      _setupForTimeline(testTimelineJson);
    });

    Future<void> pumpTimelineBody(
      WidgetTester tester,
      TimelineController controller,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        const TimelineScreenBody(),
        timeline: controller,
      ));
      // Delay to ensure the timeline has started.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds flame chart with data', windowSize,
        (WidgetTester tester) async {
      await pumpTimelineBody(tester, TimelineController());
      await tester.pumpAndSettle();
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byKey(TimelineScreen.emptyTimelineKey), findsNothing);
    });

    testWidgetsWithWindowSize('builds flame chart with no data', windowSize,
        (WidgetTester tester) async {
      _setupForTimeline({});
      await pumpTimelineBody(tester, TimelineController());
      await tester.pumpAndSettle();
      expect(find.byType(TimelineFlameChart), findsNothing);
      expect(
        find.byKey(TimelineScreen.emptyTimelineKey),
        findsOneWidget,
      );
    });
  });
}
