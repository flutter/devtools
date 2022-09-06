// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/listenable.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_metrics/raster_metrics.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_flame_chart.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_app/src/ui/tab.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../test_data/performance.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late MockPerformanceController controller;

  Future<void> _setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) async {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson)!,
      ),
    );
    final app = fakeServiceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    when(app.flutterVersionNow).thenReturn(
      FlutterVersion.parse((await fakeServiceManager.flutterVersion).json!),
    );

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(OfflineModeController, OfflineModeController());
    when(serviceManager.connectedApp!.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
  }

  group('TabbedPerformanceView', () {
    setUp(() async {
      await _setUpServiceManagerWithTimeline(testTimelineJson);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(NotificationService, NotificationService());
      controller = createMockPerformanceControllerWithDefaults();
      frameAnalysisSupported = true;
      rasterMetricsSupported = true;
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
          TabbedPerformanceView(
            controller: controller,
            processing: false,
            processingProgress: 0.0,
          ),
          performance: controller,
        ),
      );
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('builds content successfully', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpView(tester);

        expect(find.byType(AnalyticsTabbedView), findsOneWidget);
        expect(find.byType(DevToolsTab), findsNWidgets(3));

        expect(find.text('Timeline Events'), findsOneWidget);
        expect(find.text('Frame Analysis'), findsOneWidget);
        expect(find.text('Raster Metrics'), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds content for Timeline Events tab', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpView(tester);

        expect(find.byType(AnalyticsTabbedView), findsOneWidget);
        expect(find.byType(DevToolsTab), findsNWidgets(3));

        // Timeline Events tab should be selected by default
        expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
        expect(find.byKey(timelineSearchFieldKey), findsOneWidget);
        expect(find.byType(TimelineEventsView), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds content for Frame Analysis tab with selected frame', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        final frame0 = testFrame0.shallowCopy()
          ..setEventFlow(animatorBeginFrameEvent)
          ..setEventFlow(goldenRasterTimelineEvent);

        controller = createMockPerformanceControllerWithDefaults();
        when(controller.selectedFrame)
            .thenReturn(FixedValueListenable<FlutterFrame?>(frame0));

        await pumpView(tester, performanceController: controller);

        expect(find.byType(AnalyticsTabbedView), findsOneWidget);
        expect(find.byType(DevToolsTab), findsNWidgets(3));

        await tester.tap(find.text('Frame Analysis'));
        await tester.pumpAndSettle();

        expect(find.byType(FlutterFrameAnalysisView), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'builds content for Frame Analysis tab without selected frame',
        windowSize, (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpView(tester);

        expect(find.byType(AnalyticsTabbedView), findsOneWidget);
        expect(find.byType(DevToolsTab), findsNWidgets(3));

        await tester.tap(find.text('Frame Analysis'));
        await tester.pumpAndSettle();

        expect(
          find.text('Select a frame above to view analysis data.'),
          findsOneWidget,
        );
      });
    });

    testWidgetsWithWindowSize(
        'builds content for Raster Metrics tab', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        await pumpView(tester);
        await tester.pumpAndSettle();
        expect(find.byType(AnalyticsTabbedView), findsOneWidget);
        expect(find.byType(DevToolsTab), findsNWidgets(3));

        await tester.tap(find.text('Raster Metrics'));
        await tester.pumpAndSettle();

        expect(find.byType(RenderingLayerVisualizer), findsOneWidget);
        expect(find.text('Take Snapshot'), findsOneWidget);
        expect(find.byType(ClearButton), findsOneWidget);
      });
    });

    testWidgetsWithWindowSize(
        'only shows Timeline Events tab for non-flutter app', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await _setUpServiceManagerWithTimeline({});
        final app = fakeServiceManager.connectedApp!;
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
        expect(find.text('Raster Metrics'), findsNothing);
      });
    });
  });
}
