// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/event_details.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/legacy/timeline_flame_chart.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_events_view.dart';
import 'package:devtools_app/src/shared/charts/flame_chart.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../../test_infra/matchers/matchers.dart';
import '../../../test_infra/test_data/performance.dart';

void main() {
  FakeServiceConnectionManager fakeServiceConnection;
  late PerformanceController controller;

  void setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) {
    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson)!,
      ),
    );
    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
  }

  group('$TimelineEventsView', () {
    setUp(() {
      setUpServiceManagerWithTimeline(testTimelineJson);
    });

    Future<void> pumpPerformanceScreenBody(
      WidgetTester tester, {
      PerformanceController? performanceController,
    }) async {
      controller = performanceController ?? PerformanceController();

      // Await a small delay to allow the PerformanceController to complete
      // initialization.
      await Future.delayed(const Duration(seconds: 1));

      await tester.pumpWidget(
        wrapWithControllers(
          const PerformanceScreenBody(),
          performance: controller,
        ),
      );
      await tester.pump();

      // Ensure the Timeline Events tab is selected.
      final timelineEventsTabFinder = find.text('Timeline Events');
      expect(timelineEventsTabFinder, findsOneWidget);
      await tester.tap(timelineEventsTabFinder);
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize(
      'builds header with search field',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          setUpServiceManagerWithTimeline({});
          await pumpPerformanceScreenBody(tester);
          expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
          expect(
            find.byType(SearchField<LegacyTimelineEventsController>),
            findsOneWidget,
          );
          expect(find.byType(FlameChartHelpButton), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'can show help dialog',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          setUpServiceManagerWithTimeline({});
          await pumpPerformanceScreenBody(tester);

          final helpButtonFinder = find.byType(FlameChartHelpButton);
          expect(helpButtonFinder, findsOneWidget);
          await tester.tap(helpButtonFinder);
          await tester.pumpAndSettle();
          expect(find.text('Flame Chart Help'), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds flame chart with data',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreenBody(tester);
          expect(
            find.byKey(TimelineEventsView.emptyTimelineKey),
            findsNothing,
          );

          expect(find.byType(TimelineFlameChart), findsOneWidget);
          expect(find.byType(EventDetails), findsOneWidget);

          // Verify the state of the splitter.
          final splitFinder = find.byType(Split);
          expect(splitFinder, findsOneWidget);
          final Split splitter = tester.widget(splitFinder);
          expect(splitter.initialFractions[0], equals(0.7));
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds flame chart with no data',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          setUpServiceManagerWithTimeline({});
          await pumpPerformanceScreenBody(tester);
          expect(
            find.byKey(TimelineEventsView.emptyTimelineKey),
            findsOneWidget,
          );

          expect(find.byType(TimelineFlameChart), findsNothing);
          expect(find.byType(EventDetails), findsNothing);
          expect(find.byType(Split), findsNothing);
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds flame chart with selected frame',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreenBody(tester);
          controller
            ..flutterFramesController.addFrame(testFrame1.shallowCopy())
            ..timelineEventsController.addTimelineEvent(goldenUiTimelineEvent)
            ..timelineEventsController
                .addTimelineEvent(goldenRasterTimelineEvent);
          final data = controller.data!;
          expect(data.frames.length, equals(1));
          controller.flutterFramesController
              .handleSelectedFrame(data.frames.first);
          await tester.pumpAndSettle();
        });
        expect(find.byType(TimelineFlameChart), findsOneWidget);
        await expectLater(
          find.byType(TimelineFlameChart),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/timeline_flame_chart_with_selected_frame.png',
          ),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
      skip: kIsWeb,
    );
  });
}
