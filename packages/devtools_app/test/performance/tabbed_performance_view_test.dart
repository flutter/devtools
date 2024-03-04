// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/perfetto.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_events_view.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_app/src/shared/charts/flame_chart.dart';
import 'package:devtools_app/src/shared/ui/tab.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../test_infra/test_data/performance.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockPerformanceController controller;
  late MockFlutterFramesController mockFlutterFramesController;
  late MockTimelineEventsController mockTimelineEventsController;

  Future<void> setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) async {
    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson)!,
      ),
    );
    final app = fakeServiceConnection.serviceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    when(app.flutterVersionNow).thenReturn(
      FlutterVersion.parse(
        (await fakeServiceConnection.serviceManager.flutterVersion).json!,
      ),
    );

    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(OfflineModeController, OfflineModeController());
    when(serviceConnection.serviceManager.connectedApp!.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
  }

  group('TabbedPerformanceView', () {
    setUp(() async {
      await setUpServiceManagerWithTimeline(testTimelineJson);
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(NotificationService, NotificationService());
      controller = createMockPerformanceControllerWithDefaults();
      mockTimelineEventsController = MockTimelineEventsController();
      when(mockTimelineEventsController.data).thenReturn(controller.data);
      when(mockTimelineEventsController.status).thenReturn(
        const FixedValueListenable<EventsControllerStatus>(
          EventsControllerStatus.ready,
        ),
      );
      when(controller.timelineEventsController)
          .thenReturn(mockTimelineEventsController);
      when(mockTimelineEventsController.isActiveFeature).thenReturn(false);
      mockFlutterFramesController = MockFlutterFramesController();
      when(mockFlutterFramesController.displayRefreshRate)
          .thenReturn(const FixedValueListenable<double>(defaultRefreshRate));
      when(mockFlutterFramesController.selectedFrame)
          .thenReturn(const FixedValueListenable<FlutterFrame?>(null));
      when(mockFlutterFramesController.isActiveFeature).thenReturn(false);
      when(controller.flutterFramesController)
          .thenReturn(mockFlutterFramesController);
    });

    Future<void> pumpView(
      WidgetTester tester, {
      MockPerformanceController? performanceController,
      bool runAsync = false,
    }) async {
      if (performanceController != null) {
        controller = performanceController;
      }

      if (runAsync) {
        // Await a small delay to allow the PerformanceController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));
      }

      await tester.pumpWidget(
        wrapWithControllers(
          const TabbedPerformanceView(),
          performance: controller,
        ),
      );
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize(
      'builds content successfully',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          await pumpView(tester);

          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsNWidgets(3));

          expect(find.text('Timeline Events'), findsOneWidget);
          expect(find.text('Frame Analysis'), findsOneWidget);
          expect(find.text('Raster Stats'), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds content for Frame Analysis tab with selected frame',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          final frame0 = testFrame0.shallowCopy()
            ..setEventFlow(animatorBeginFrameEvent)
            ..setEventFlow(goldenRasterTimelineEvent);

          when(mockFlutterFramesController.selectedFrame)
              .thenReturn(FixedValueListenable<FlutterFrame?>(frame0));

          await pumpView(tester, performanceController: controller);

          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsNWidgets(3));

          // The frame analysis tab should be selected by default.
          expect(find.byType(FlutterFrameAnalysisView), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds content for Frame Analysis tab without selected frame',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          await pumpView(tester);

          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsNWidgets(3));

          // The frame analysis tab should be selected by default.
          expect(
            find.text('Select a frame above to view analysis data.'),
            findsOneWidget,
          );
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds content for Raster Stats tab',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          await pumpView(tester);
          await tester.pumpAndSettle();
          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsNWidgets(3));

          await tester.tap(find.text('Raster Stats'));
          await tester.pumpAndSettle();

          expect(find.byType(RasterStatsView), findsOneWidget);
          expect(find.text('Take Snapshot'), findsOneWidget);
          expect(find.byType(ClearButton), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds content for Timeline Events tab',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          await pumpView(tester);

          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsNWidgets(3));

          await tester.tap(find.text('Timeline Events'));
          await tester.pumpAndSettle();

          expect(find.byType(TraceCategoriesButton), findsOneWidget);
          expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
          expect(find.byType(FlameChartHelpButton), findsOneWidget);
          expect(find.byType(TimelineEventsTabView), findsOneWidget);
          expect(find.byType(EmbeddedPerfetto), findsOneWidget);
        });
      },
    );

    testWidgetsWithWindowSize(
      'only shows Timeline Events tab for non-flutter app',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await setUpServiceManagerWithTimeline({});
          final app = fakeServiceConnection.serviceManager.connectedApp!;
          mockConnectedApp(
            app,
            isFlutterApp: false,
            isProfileBuild: false,
            isWebApp: false,
          );
          when(app.flutterVersionNow).thenReturn(null);

          await pumpView(tester);
          await tester.pumpAndSettle();
          expect(find.byType(AnalyticsTabbedView), findsOneWidget);
          expect(find.byType(DevToolsTab), findsOneWidget);
          expect(find.text('Timeline Events'), findsOneWidget);
          expect(find.text('Frame Analysis'), findsNothing);
          expect(find.text('Raster Stats'), findsNothing);
        });
      },
    );
  });
}
