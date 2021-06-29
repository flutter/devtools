// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/flutter_frames_chart.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_model.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/performance_test_data.dart';
import 'support/wrappers.dart';

void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    @required List<FlutterFrame> frames,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      FlutterFramesChart(frames, defaultRefreshRate),
      performance: PerformanceController(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterFramesChart), findsOneWidget);
  }

  group('FlutterFramesChart', () {
    setUp(() async {
      setGlobal(ServiceConnectionManager, FakeServiceManager());
    });

    testWidgets('builds with no frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: []);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
    });

    testWidgets('builds with frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: [testFrame0, testFrame1]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNWidgets(2));
    });

    testWidgets('builds with janky frame', (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrame]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui = tester.widget(find.byKey(const Key('frame jankyFrame - ui')))
          as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame jankyFrame - raster')))
              as Container;
      expect(raster.color, equals(rasterJankColor));
    });

    testWidgets('builds with janky frame ui only', (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrameUiOnly]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame jankyFrameUiOnly - ui')))
              as Container;
      expect(ui.color, equals(uiJankColor));
      final raster = tester
              .widget(find.byKey(const Key('frame jankyFrameUiOnly - raster')))
          as Container;
      expect(raster.color, equals(mainRasterColor));
    });

    testWidgets('builds with janky frame raster only',
        (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrameRasterOnly]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui = tester
              .widget(find.byKey(const Key('frame jankyFrameRasterOnly - ui')))
          as Container;
      expect(ui.color, equals(mainUiColor));
      final raster = tester.widget(
              find.byKey(const Key('frame jankyFrameRasterOnly - raster')))
          as Container;
      expect(raster.color, equals(rasterJankColor));
    });
  });

  group('FlutterFramesChartItem', () {
    testWidgets('builds for selected frame', (WidgetTester tester) async {
      await tester.pumpWidget(
        // FlutterFramesChartItem needs to be wrapped in Material,
        // Directionality, and Overlay in order to pump the widget and test.
        Material(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) {
                    return FlutterFramesChartItem(
                      frame: testFrame0,
                      selected: true,
                      msPerPx: 1,
                      availableChartHeight: 100.0,
                      displayRefreshRate: defaultRefreshRate,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(FlutterFramesChartItem.selectedFrameIndicatorKey),
          findsOneWidget);
    });
  });
}
