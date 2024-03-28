// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_hints.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_time_visualizer.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/matchers/matchers.dart';
import '../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  const windowSize = Size(1500.0, 500.0);

  group('FlutterFrameAnalysisView', () {
    late FlutterFrame frame;
    late FrameAnalysis frameAnalysis;
    late MockEnhanceTracingController mockEnhanceTracingController;
    late RebuildCountModel rebuildCountModel;

    setUp(() {
      frame = FlutterFrame4.frameWithExtras;
      frameAnalysis = FrameAnalysis(frame);
      mockEnhanceTracingController = MockEnhanceTracingController();
      rebuildCountModel = RebuildCountModel();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineModeController, OfflineModeController());
      final fakeServiceConnection = FakeServiceConnectionManager();
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(NotificationService, NotificationService());
      mockConnectedApp(
        fakeServiceConnection.serviceManager.connectedApp!,
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
        wrapSimple(
          FlutterFrameAnalysisView(
            frameAnalysis: analysis,
            enhanceTracingController: mockEnhanceTracingController,
            rebuildCountModel: rebuildCountModel,
            displayRefreshRateNotifier:
                const FixedValueListenable<double>(defaultRefreshRate),
          ),
        ),
      );
      expect(find.byType(FlutterFrameAnalysisView), findsOneWidget);
    }

    testWidgetsWithWindowSize(
      'builds with null data',
      windowSize,
      (WidgetTester tester) async {
        await pumpAnalysisView(tester, null);

        expect(
          find.textContaining('No analysis data available for this frame.'),
          findsOneWidget,
        );
        expect(find.byType(FrameHints), findsNothing);
        expect(find.byType(FrameTimeVisualizer), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds with non-null data',
      windowSize,
      (WidgetTester tester) async {
        await pumpAnalysisView(tester, frameAnalysis);

        expect(
          find.textContaining('No analysis data available for this frame.'),
          findsNothing,
        );
        expect(find.byType(FrameHints), findsOneWidget);
        expect(find.byType(FrameTimeVisualizer), findsOneWidget);
      },
    );

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

      testWidgetsWithWindowSize(
        'builds successfully',
        windowSize,
        (WidgetTester tester) async {
          await pumpVisualizer(tester, frameAnalysis);

          expect(find.text('UI phases:'), findsOneWidget);
          expect(find.textContaining('Build - '), findsOneWidget);

          // The flex values are too small to show the text for these phases.
          expect(find.textContaining('Layout - '), findsNothing);
          expect(find.textContaining('Paint - '), findsNothing);

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
              '../../test_infra/goldens/performance/frame_analysis/frame_time_visualizer.png',
            ),
          );
        },
      );

      testWidgetsWithWindowSize(
        'builds with icons only for narrow screen',
        const Size(200.0, 500.0),
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
              '../../test_infra/goldens/performance/frame_analysis/frame_time_visualizer_icons_only.png',
            ),
          );
        },
      );

      testWidgetsWithWindowSize(
        'builds for frame with shader compilation',
        windowSize,
        (WidgetTester tester) async {
          frame = testFrameWithShaderJank;
          frameAnalysis = FrameAnalysis(frame);
          await pumpVisualizer(tester, frameAnalysis);

          expect(find.text('UI phases:'), findsOneWidget);
          expect(find.textContaining('Build - '), findsOneWidget);

          // The flex values are too small to show the text for these phases.
          expect(find.textContaining('Layout - '), findsNothing);
          expect(find.textContaining('Paint - '), findsNothing);

          expect(find.byIcon(Icons.build), findsOneWidget);
          expect(find.byIcon(Icons.auto_awesome_mosaic), findsOneWidget);
          expect(find.byIcon(Icons.format_paint), findsOneWidget);

          expect(find.text('Raster phase:'), findsNothing);
          expect(find.textContaining('Raster - '), findsNothing);
          expect(find.byIcon(Icons.grid_on), findsOneWidget);

          expect(find.text('Raster phases:'), findsOneWidget);

          // The flex value for this phase is too narrow for text, but the
          // icon is visible.
          expect(find.textContaining('Shader compilation - '), findsNothing);
          expect(find.byIcon(Icons.image_outlined), findsOneWidget);

          expect(find.textContaining('Other raster - '), findsOneWidget);

          await expectLater(
            find.byType(FrameTimeVisualizer),
            matchesDevToolsGolden(
              '../../test_infra/goldens/performance/frame_analysis/frame_time_visualizer_with_shader_compilation.png',
            ),
          );
        },
      );
    });
  });
}
