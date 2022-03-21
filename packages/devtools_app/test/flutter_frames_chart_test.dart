// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

@TestOn('vm')
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/performance/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'test_data/performance_test_data.dart';

void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    required List<FlutterFrame> frames,
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
      final fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      frameAnalysisSupported = true;
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
      final ui =
          tester.widget(find.byKey(const Key('frame 2 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 2 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
      expect(find.byType(FrameAnalysisIcon), findsOneWidget);
    });

    testWidgets('builds with janky frame ui only', (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrameUiOnly]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 3 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 3 - raster'))) as Container;
      expect(raster.color, equals(mainRasterColor));
      expect(find.byType(FrameAnalysisIcon), findsOneWidget);
    });

    testWidgets('builds with janky frame raster only',
        (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrameRasterOnly]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 4 - ui'))) as Container;
      expect(ui.color, equals(mainUiColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 4 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
      expect(find.byType(FrameAnalysisIcon), findsNothing);
    });

    testWidgets('builds with janky frame with shader jank',
        (WidgetTester tester) async {
      await pumpChart(tester, frames: [testFrameWithShaderJank]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 5 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 5 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
      final shaders = tester.widget(find.byKey(const Key('frame 5 - shaders')))
          as Container;
      expect(shaders.color, equals(shaderCompilationColor.background));
      expect(find.byType(ShaderJankWarningIcon), findsOneWidget);
    });

    testWidgets('builds with janky frame with subtle shader jank',
        (WidgetTester tester) async {
      await pumpChart(tester, frames: [testFrameWithSubtleShaderJank]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 6 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 6 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
      final shaders = tester.widget(find.byKey(const Key('frame 6 - shaders')))
          as Container;
      expect(shaders.color, equals(shaderCompilationColor.background));
      expect(find.byType(ShaderJankWarningIcon), findsNothing);
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
                      controller: MockPerformanceController(),
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
