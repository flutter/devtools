// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_model.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/flutter/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    @required List<TimelineFrame> frames,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      FlutterFramesChart(frames, 20, defaultRefreshRate),
      timeline: TimelineController(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterFramesChart), findsOneWidget);
  }

  group('TimelineScreen', () {
    setUp(() async {
      setGlobal(
          ServiceConnectionManager, FakeServiceManager(useFakeService: true));
    });

    testWidgets('builds with no frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: []);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
    });

    testWidgets('builds with frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: [testFrame1, testFrame2]);
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
  });
}

final testFrame1 = TimelineFrame('testFrame1')
  ..eventFlows[0] = (goldenUiTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 10)
      ..end = const Duration(milliseconds: 20)))
  ..eventFlows[1] = (goldenRasterTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 15)
      ..end = const Duration(milliseconds: 25)));

final testFrame2 = TimelineFrame('testFrame2')
  ..eventFlows[0] = (goldenUiTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 30)
      ..end = const Duration(milliseconds: 35)))
  ..eventFlows[1] = (goldenRasterTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 33)
      ..end = const Duration(milliseconds: 40)));

final jankyFrame = TimelineFrame('jankyFrame')
  ..eventFlows[0] = (goldenUiTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 50)
      ..end = const Duration(milliseconds: 70)))
  ..eventFlows[1] = (goldenRasterTimelineEvent.deepCopy()
    ..time = (TimeRange()
      ..start = const Duration(milliseconds: 68)
      ..end = const Duration(milliseconds: 75)));
