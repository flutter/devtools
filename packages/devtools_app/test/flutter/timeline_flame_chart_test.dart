// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
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
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
    });

    testWidgets('builds frame based timeline', (WidgetTester tester) async {
      // Set a wide enough screen width that we do not run into overflow.
      await setWindowSize(const Size(1599.0, 1000.0));

      final mockData = MockFrameBasedTimelineData();
      when(mockData.displayDepth).thenReturn(8);
      when(mockData.selectedFrame).thenReturn(testFrame);
      final controllerWithData = TimelineController()
        ..frameBasedTimeline.data = mockData;
      await tester.pumpWidget(wrapWithProvidedController(
        TimelineScreenBody(),
        timelineController: controllerWithData,
      ));
      expect(find.byType(FrameBasedTimelineFlameChart), findsOneWidget);
      expect(find.text('TODO Full Timeline Flame Chart'), findsNothing);
    });

    testWidgets('builds full timeline', (WidgetTester tester) async {
      // Set a wide enough screen width that we do not run into overflow.
      await setWindowSize(const Size(1599.0, 1000.0));

      await tester.pumpWidget(wrapWithProvidedController(
        TimelineScreenBody(),
        timelineController: TimelineController()
          ..timelineMode = TimelineMode.full,
      ));
      expect(find.byType(FrameBasedTimelineFlameChart), findsNothing);
      expect(find.text('TODO Full Timeline Flame Chart'), findsOneWidget);
    });
  });
}
