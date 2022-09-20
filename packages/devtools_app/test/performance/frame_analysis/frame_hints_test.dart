// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/performance/panes/controls/enhance_tracing/enhance_tracing_model.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis_model.dart';
import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_hints.dart';
import 'package:devtools_app/src/screens/performance/performance_controller.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_data/performance.dart';

void main() {
  const windowSize = Size(4000.0, 1000.0);

  group('FrameHints', () {
    late MockEnhanceTracingController mockEnhanceTracingController;
    late MockFrameAnalysis mockFrameAnalysis;
    late MockFramePhase mockBuildPhase;
    late MockFramePhase mockLayoutPhase;
    late MockFramePhase mockPaintPhase;
    late MockFramePhase mockRasterPhase;

    setUp(() {
      mockEnhanceTracingController = MockEnhanceTracingController();
      mockFrameAnalysis = MockFrameAnalysis();
      mockBuildPhase = MockFramePhase();
      when(mockBuildPhase.title).thenReturn(FramePhaseType.build.eventName);
      when(mockBuildPhase.type).thenReturn(FramePhaseType.build);
      mockLayoutPhase = MockFramePhase();
      when(mockLayoutPhase.title).thenReturn(FramePhaseType.layout.eventName);
      when(mockLayoutPhase.type).thenReturn(FramePhaseType.layout);
      mockPaintPhase = MockFramePhase();
      when(mockPaintPhase.title).thenReturn(FramePhaseType.paint.eventName);
      when(mockPaintPhase.type).thenReturn(FramePhaseType.paint);
      mockRasterPhase = MockFramePhase();
      when(mockRasterPhase.title).thenReturn(FramePhaseType.raster.eventName);
      when(mockRasterPhase.type).thenReturn(FramePhaseType.raster);

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

    Future<void> pumpHints(
      WidgetTester tester,
      FrameAnalysis frameAnalysis,
    ) async {
      await tester.pumpWidget(
        wrapWithControllers(
          FrameHints(
            frameAnalysis: frameAnalysis,
            enhanceTracingController: mockEnhanceTracingController,
          ),
          performance: PerformanceController(),
        ),
      );
      expect(find.byType(FrameHints), findsOneWidget);
    }

    void _mockFrameAnalysis({
      required MockFrameAnalysis frameAnalysis,
      required FlutterFrame frame,
      FramePhase? longestUiPhase,
      bool buildsTracked = false,
      bool layoutsTracked = false,
      bool paintsTracked = false,
      int saveLayerCount = 0,
      int intrinsicsCount = 0,
    }) {
      when(frameAnalysis.frame).thenReturn(frame);
      frame.enhanceTracingState = EnhanceTracingState(
        builds: buildsTracked,
        layouts: layoutsTracked,
        paints: paintsTracked,
      );
      when(frameAnalysis.longestUiPhase).thenReturn(
        longestUiPhase ?? mockBuildPhase,
      );
      when(frameAnalysis.saveLayerCount).thenReturn(saveLayerCount);
      when(frameAnalysis.intrinsicOperationsCount).thenReturn(intrinsicsCount);
    }

    testWidgetsWithWindowSize(
        'does not show hints when frame is not janky', windowSize,
        (WidgetTester tester) async {
      when(mockFrameAnalysis.frame).thenReturn(testFrame0);
      await pumpHints(tester, mockFrameAnalysis);

      expect(
        find.text('No suggestions for this frame - no jank detected.'),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize('does show hints for janky frame', windowSize,
        (WidgetTester tester) async {
      _mockFrameAnalysis(frameAnalysis: mockFrameAnalysis, frame: jankyFrame);
      await pumpHints(tester, mockFrameAnalysis);

      expect(
        find.text('No suggestions for this frame - no jank detected.'),
        findsNothing,
      );
      expect(find.text('UI Jank Detected'), findsOneWidget);
      expect(find.byType(EnhanceTracingHint), findsOneWidget);
      expect(find.byType(IntrinsicOperationsHint), findsNothing);
      expect(find.text('Raster Jank Detected'), findsOneWidget);
      expect(find.byType(RasterStatsHint), findsOneWidget);
      expect(find.byType(CanvasSaveLayerHint), findsNothing);
      expect(find.byType(ShaderCompilationHint), findsNothing);
    });

    group('enhance tracing hints', () {
      testWidgetsWithWindowSize(
          'shows hint when build tracing was enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
          buildsTracked: true,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Build was the longest UI phase in this frame. Since "Track Widget '
            'Builds" was enabled while this frame was drawn, you should be able'
            ' to see timeline events for each widget built.',
          ),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize(
          'shows hint when build tracing was not enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Build was the longest UI phase in this frame. Consider enabling '
            '"Track Widget Builds" from the ',
          ),
          findsOneWidget,
        );
        expect(find.byType(SmallEnhanceTracingButton), findsOneWidget);
        expect(
          find.richTextContaining(
            ' options above and reproducing the behavior in your app.',
          ),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize(
          'shows hint when layout tracing was enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
          longestUiPhase: mockLayoutPhase,
          layoutsTracked: true,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Layout was the longest UI phase in this frame. Since "Track '
            'Layouts" was enabled while this frame was drawn, you should be '
            'able to see timeline events for each render object laid out.',
          ),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize(
          'shows hint when layout tracing was not enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
          longestUiPhase: mockLayoutPhase,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Layout was the longest UI phase in this frame. Consider enabling '
            '"Track Layouts" from the ',
          ),
          findsOneWidget,
        );
        expect(find.byType(SmallEnhanceTracingButton), findsOneWidget);
        expect(
          find.richTextContaining(
            ' options above and reproducing the behavior in your app.',
          ),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize(
          'shows hint when paint tracing was enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
          longestUiPhase: mockPaintPhase,
          paintsTracked: true,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Paint was the longest UI phase in this frame. Since "Track '
            'Paints" was enabled while this frame was drawn, you should be '
            'able to see timeline events for each render object painted.',
          ),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize(
          'shows hint when paint tracing was not enhanced', windowSize,
          (WidgetTester tester) async {
        _mockFrameAnalysis(
          frameAnalysis: mockFrameAnalysis,
          frame: jankyFrame,
          longestUiPhase: mockPaintPhase,
        );
        await pumpHints(tester, mockFrameAnalysis);

        expect(
          find.richTextContaining(
            'Paint was the longest UI phase in this frame. Consider enabling '
            '"Track Paints" from the ',
          ),
          findsOneWidget,
        );
        expect(find.byType(SmallEnhanceTracingButton), findsOneWidget);
        expect(
          find.richTextContaining(
            ' options above and reproducing the behavior in your app.',
          ),
          findsOneWidget,
        );
      });
    });

    testWidgetsWithWindowSize('shows intrinsic operations hint', windowSize,
        (WidgetTester tester) async {
      _mockFrameAnalysis(
        frameAnalysis: mockFrameAnalysis,
        frame: jankyFrame,
        intrinsicsCount: 5,
      );
      await pumpHints(tester, mockFrameAnalysis);

      expect(find.byType(IntrinsicOperationsHint), findsOneWidget);
      expect(
        find.richTextContaining(
          'Intrinsic passes were performed 5 times during this frame. This '
          'may negatively affect your app\'s performance.',
        ),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize('shows canvas save layer hint', windowSize,
        (WidgetTester tester) async {
      _mockFrameAnalysis(
        frameAnalysis: mockFrameAnalysis,
        frame: jankyFrame,
        saveLayerCount: 5,
      );
      await pumpHints(tester, mockFrameAnalysis);

      expect(find.byType(CanvasSaveLayerHint), findsOneWidget);
      expect(
        find.richTextContaining(
          'Canvas.saveLayer() was called 5 times during this frame. This '
          'may negatively affect your app\'s performance.',
        ),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize('shows shader compilation hint', windowSize,
        (WidgetTester tester) async {
      _mockFrameAnalysis(
        frameAnalysis: mockFrameAnalysis,
        frame: testFrameWithShaderJank,
      );
      await pumpHints(tester, mockFrameAnalysis);

      expect(find.byType(ShaderCompilationHint), findsOneWidget);
      expect(
        find.richTextContaining(
          ' of shader compilation occurred during this frame. This may '
          'negatively affect your app\'s performance',
        ),
        findsOneWidget,
      );
    });
  });
}
