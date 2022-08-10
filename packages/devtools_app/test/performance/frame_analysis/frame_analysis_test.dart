// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis_model.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_hints.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_time_visualizer.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../matchers/matchers.dart';
import '../../test_data/performance.dart';

void main() {
  const windowSize = Size(4000.0, 1000.0);

  group('FlutterFrameAnalysisView', () {
    late FlutterFrame frame;
    late FrameAnalysis frameAnalysis;
    late MockEnhanceTracingController mockEnhanceTracingController;

    setUp(() {
      frame = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      mockEnhanceTracingController = MockEnhanceTracingController();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineModeController, OfflineModeController());
      final fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(NotificationService, NotificationService());
      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );
    });

    Future<void> pumpAnalysisView(
      WidgetTester tester,
      FrameAnalysis? analysis,
    ) async {
      await tester.pumpWidget(
        wrapWithControllers(
          FlutterFrameAnalysisView(
            frameAnalysis: analysis,
            enhanceTracingController: mockEnhanceTracingController,
          ),
          performance: PerformanceController(),
        ),
      );
      expect(find.byType(FlutterFrameAnalysisView), findsOneWidget);
    }

    testWidgetsWithWindowSize('builds with null data', windowSize,
        (WidgetTester tester) async {
      await pumpAnalysisView(tester, null);

      expect(
        find.text('No analysis data available for this frame.'),
        findsOneWidget,
      );
      expect(find.byType(FrameHints), findsNothing);
      expect(find.byType(FrameTimeVisualizer), findsNothing);
    });

    testWidgetsWithWindowSize('builds with non-null data', windowSize,
        (WidgetTester tester) async {
      await pumpAnalysisView(tester, frameAnalysis);

      expect(
        find.text('No analysis data available for this frame.'),
        findsNothing,
      );
      expect(find.byType(FrameHints), findsOneWidget);
      expect(find.byType(FrameTimeVisualizer), findsOneWidget);
    });

    group('FrameTimeVisualizer', () {
      Future<void> pumpVisualizer(
        WidgetTester tester,
        FrameAnalysis frameAnalysis,
      ) async {
        await tester.pumpWidget(
          wrap(FrameTimeVisualizer(frameAnalysis: frameAnalysis)),
        );
        expect(find.byType(FrameTimeVisualizer), findsOneWidget);
      }

      testWidgetsWithWindowSize('builds successfully', windowSize,
          (WidgetTester tester) async {
        await pumpVisualizer(tester, frameAnalysis);

        expect(find.text('UI phases:'), findsOneWidget);
        expect(find.textContaining('Build - '), findsOneWidget);
        expect(find.textContaining('Layout - '), findsOneWidget);
        expect(find.textContaining('Paint - '), findsOneWidget);
        expect(find.byIcon(Icons.build), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_mosaic), findsOneWidget);
        expect(find.byIcon(Icons.format_paint), findsOneWidget);

        expect(find.text('Raster phase:'), findsOneWidget);
        expect(find.textContaining('Raster - '), findsOneWidget);
        expect(find.byIcon(Icons.grid_on), findsOneWidget);

        expect(find.text('Raster phases:'), findsNothing);
        expect(find.textContaining('Shader compilation'), findsNothing);
        expect(find.textContaining('Other raster'), findsNothing);
        expect(find.byIcon(Icons.image_outlined), findsNothing);

        await expectLater(
          find.byType(FrameTimeVisualizer),
          matchesDevToolsGolden(
            'goldens/performance/frame_time_visualizer.png',
          ),
        );
      });

      testWidgetsWithWindowSize(
          'builds with icons only for narrow screen', const Size(200.0, 1000.0),
          (WidgetTester tester) async {
        await pumpVisualizer(tester, frameAnalysis);

        expect(find.text('UI phases:'), findsOneWidget);
        expect(find.textContaining('Build - '), findsNothing);
        expect(find.textContaining('Layout - '), findsNothing);
        expect(find.textContaining('Paint - '), findsNothing);
        expect(find.byIcon(Icons.build), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_mosaic), findsOneWidget);
        expect(find.byIcon(Icons.format_paint), findsOneWidget);

        expect(find.text('Raster phase:'), findsOneWidget);
        expect(find.textContaining('Raster - '), findsNothing);
        expect(find.byIcon(Icons.grid_on), findsOneWidget);

        expect(find.text('Raster phases:'), findsNothing);
        expect(find.textContaining('Shader compilation'), findsNothing);
        expect(find.textContaining('Other raster'), findsNothing);
        expect(find.byIcon(Icons.image_outlined), findsNothing);

        await expectLater(
          find.byType(FrameTimeVisualizer),
          matchesDevToolsGolden(
            'goldens/performance/frame_time_visualizer_icons_only.png',
          ),
        );
      });

      testWidgetsWithWindowSize(
          'builds for frame with shader compilation', windowSize,
          (WidgetTester tester) async {
        frame = testFrame0.shallowCopy()
          ..setEventFlow(goldenUiTimelineEvent)
          ..setEventFlow(rasterTimelineEventWithSubtleShaderJank);
        frameAnalysis = FrameAnalysis(frame);
        await pumpVisualizer(tester, frameAnalysis);

        expect(find.text('UI phases:'), findsOneWidget);
        expect(find.textContaining('Build - '), findsOneWidget);
        expect(find.textContaining('Layout - '), findsOneWidget);
        expect(find.textContaining('Paint - '), findsOneWidget);
        expect(find.byIcon(Icons.build), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_mosaic), findsOneWidget);
        expect(find.byIcon(Icons.format_paint), findsOneWidget);

        expect(find.text('Raster phase:'), findsNothing);
        expect(find.textContaining('Raster - '), findsNothing);
        expect(find.byIcon(Icons.grid_on), findsOneWidget);

        expect(find.text('Raster phases:'), findsOneWidget);
        expect(find.textContaining('Shader compilation - '), findsOneWidget);
        expect(find.textContaining('Other raster - '), findsOneWidget);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);

        await expectLater(
          find.byType(FrameTimeVisualizer),
          matchesDevToolsGolden(
            'goldens/performance/frame_time_visualizer_with_shader_compilation.png',
          ),
        );
      });
    });
  });
}
