// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/event_details.dart';
import 'package:devtools_app/src/timeline/flutter/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_flame_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_screen.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  TimelineScreen screen;
  FakeServiceManager fakeServiceManager;

  group('TimelineScreen', () {
    setUp(() {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      screen = const TimelineScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('builds proper content for timeline modes',
        (WidgetTester tester) async {
      // Set a wide enough screen width that we do not run into overflow.
      await setWindowSize(const Size(1599.0, 1000.0));
      await tester.pumpWidget(wrap(TimelineScreenBody()));
      expect(find.byType(TimelineScreenBody), findsOneWidget);
      final TimelineScreenBodyState state =
          tester.state(find.byType(TimelineScreenBody));

      // Verify the state of the splitter.
      final splitFinder = find.byType(Split);
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFirstFraction, equals(0.6));

      // Verify TimelineMode.frameBased content.
      expect(state.controller.timelineMode, equals(TimelineMode.frameBased));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Record'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.byType(FlutterFramesChart), findsOneWidget);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byType(EventDetails), findsOneWidget);

      // Switch timeline mode and pump.
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Verify TimelineMode.full content.
      expect(state.controller.timelineMode, equals(TimelineMode.full));
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.byType(FlutterFramesChart), findsNothing);
      expect(find.byType(TimelineFlameChart), findsOneWidget);
      expect(find.byType(EventDetails), findsOneWidget);
    });
  });
}
