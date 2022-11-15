// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frames_chart.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/performance.dart';

void main() {
  late FlutterFramesController framesController;

  Future<void> pumpChart(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        FlutterFramesChart(framesController),
        bannerMessages: BannerMessagesController(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FlutterFramesChart), findsOneWidget);
  }

  group('FlutterFramesChart', () {
    setUp(() async {
      final fakeServiceManager = FakeServiceManager();
      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());

      framesController = FlutterFramesController(
        createMockPerformanceControllerWithDefaults(),
      );

      // This flag should never be turned on in production.
      expect(debugFrames, isFalse);
    });

    testWidgets('builds with no frames', (WidgetTester tester) async {
      framesController.clearData();
      await pumpChart(tester);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
    });

    testWidgets('builds nothing when visibility is false',
        (WidgetTester tester) async {
      framesController
        ..addFrame(testFrame0)
        ..addFrame(testFrame1)
        ..toggleShowFlutterFrames(false);

      await pumpChart(tester);
      expect(find.byType(FramesChartControls), findsNothing);
      expect(find.byType(Legend), findsNothing);
      expect(find.byType(AverageFPS), findsNothing);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
    });

    testWidgets('builds with frames', (WidgetTester tester) async {
      framesController
        ..addFrame(testFrame0)
        ..addFrame(testFrame1);

      await pumpChart(tester);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNWidgets(2));
    });

    testWidgets('builds with janky frame', (WidgetTester tester) async {
      framesController.addFrame(jankyFrame);

      await pumpChart(tester);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 2 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 2 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
    });

    testWidgets('builds with janky frame ui only', (WidgetTester tester) async {
      framesController.addFrame(jankyFrameUiOnly);

      await pumpChart(tester);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 3 - ui'))) as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 3 - raster'))) as Container;
      expect(raster.color, equals(mainRasterColor));
    });

    testWidgets('builds with janky frame raster only',
        (WidgetTester tester) async {
      framesController.addFrame(jankyFrameRasterOnly);

      await pumpChart(tester);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui =
          tester.widget(find.byKey(const Key('frame 4 - ui'))) as Container;
      expect(ui.color, equals(mainUiColor));
      final raster =
          tester.widget(find.byKey(const Key('frame 4 - raster'))) as Container;
      expect(raster.color, equals(rasterJankColor));
    });

    testWidgets('builds with janky frame with shader jank',
        (WidgetTester tester) async {
      framesController.addFrame(testFrameWithShaderJank);

      await pumpChart(tester);
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
      framesController.addFrame(testFrameWithSubtleShaderJank);

      await pumpChart(tester);
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

    testWidgets('can pause and resume frame recording from controls',
        (WidgetTester tester) async {
      await pumpChart(tester);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      expect(framesController.recordingFrames.value, isTrue);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(framesController.recordingFrames.value, isFalse);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      expect(framesController.recordingFrames.value, isTrue);
    });
  });

  group('FlutterFramesChartItem', () {
    testWidgets('builds for selected frame', (WidgetTester tester) async {
      setGlobal(IdeTheme, IdeTheme());

      await tester.pumpWidget(
        // FlutterFramesChartItem needs to be wrapped in Material,
        // Directionality, and Overlay in order to pump the widget and test.
        wrap(
          Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  return FlutterFramesChartItem(
                    index: 0,
                    framesController:
                        createMockPerformanceControllerWithDefaults()
                            .flutterFramesController,
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
      );
      expect(
        find.byKey(FlutterFramesChartItem.selectedFrameIndicatorKey),
        findsOneWidget,
      );
    });
  });
}
