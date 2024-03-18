// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/ui/colors.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  late FlutterFramesController framesController;

  Future<void> pumpChart(
    WidgetTester tester, {
    bool offlineMode = false,
    bool impellerEnabled = false,
  }) async {
    await tester.pumpWidget(
      wrap(
        FlutterFramesChart(
          framesController,
          offlineMode: offlineMode,
          impellerEnabled: impellerEnabled,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FlutterFramesChart), findsOneWidget);
  }

  group('FlutterFramesChart', () {
    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      mockConnectedApp(
        fakeServiceConnection.serviceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
      setGlobal(BannerMessagesController, BannerMessagesController());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());

      framesController = FlutterFramesController(
        createMockPerformanceControllerWithDefaults(),
      );

      // This flag should never be turned on in production.
      expect(debugFrames, isFalse);
    });

    testWidgets('builds with no frames', (WidgetTester tester) async {
      framesController.clearData();
      await pumpChart(tester);
      expect(find.byType(FramesChart), findsOneWidget);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(PauseResumeButtonGroup), findsOneWidget);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
      expect(find.textContaining('Engine: Skia'), findsOneWidget);
    });

    testWidgets(
      'builds nothing when visibility is false',
      (WidgetTester tester) async {
        framesController
          ..addFrame(testFrame0)
          ..addFrame(testFrame1)
          ..toggleShowFlutterFrames(false);

        await pumpChart(tester);
        expect(find.byType(FramesChart), findsNothing);
        expect(find.byType(FramesChartControls), findsNothing);
        expect(find.byType(Legend), findsNothing);
        expect(find.byType(AverageFPS), findsNothing);
        expect(find.byType(FlutterFramesChartItem), findsNothing);
        expect(find.textContaining('Engine:'), findsNothing);
      },
    );

    testWidgets('builds with frames', (WidgetTester tester) async {
      framesController
        ..addFrame(testFrame0)
        ..addFrame(testFrame1);

      await pumpChart(tester);
      expect(find.byType(FramesChart), findsOneWidget);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNWidgets(2));
      expect(find.textContaining('Engine: Skia'), findsOneWidget);
    });

    testWidgets('builds in offline mode', (WidgetTester tester) async {
      framesController.clearData();
      await pumpChart(tester, offlineMode: true);
      expect(find.byType(FramesChart), findsOneWidget);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(PauseResumeButtonGroup), findsNothing);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.textContaining('Engine: Skia'), findsOneWidget);
    });

    testWidgets('builds with impeller enabled', (WidgetTester tester) async {
      framesController.clearData();
      await pumpChart(tester, impellerEnabled: true);
      expect(find.byType(FramesChart), findsOneWidget);
      expect(find.byType(FramesChartControls), findsOneWidget);
      expect(find.byType(PauseResumeButtonGroup), findsOneWidget);
      expect(find.byType(Legend), findsOneWidget);
      expect(find.byType(AverageFPS), findsOneWidget);
      expect(find.textContaining('Engine: Impeller'), findsOneWidget);
    });

    group('starting scroll position', () {
      const totalNumFrames = 50;
      const totalFramesInView = 15;

      setUp(() {
        var number = 0;
        var startTime = 10000;
        var elapsedTime = 20000;
        var buildTime = 10000;
        var rasterTime = 12000;
        for (var i = 0; i < totalNumFrames; i++) {
          framesController.addFrame(
            FlutterFrame.parse({
              'number': number++,
              'startTime': startTime += 50000,
              'elapsed': elapsedTime += 50000,
              'build': buildTime += 50000,
              'raster': rasterTime += 50000,
              'vsyncOverhead': 10,
            }),
          );
        }
      });

      void verifyScrollOffset(WidgetTester tester, double expectedOffset) {
        final Scrollbar scrollbar =
            tester.widget<Scrollbar>(find.byType(Scrollbar));
        final scrollController = scrollbar.controller!;
        expect(scrollController.offset, equals(expectedOffset));
      }

      testWidgets('is zero for no selected frame', (WidgetTester tester) async {
        expect(framesController.selectedFrame.value, isNull);

        await pumpChart(tester);
        expect(find.byType(FramesChart), findsOneWidget);
        expect(
          find.byType(FlutterFramesChartItem),
          findsNWidgets(totalFramesInView),
        );

        verifyScrollOffset(tester, 0.0);
      });

      testWidgets('is offset for selected frame', (WidgetTester tester) async {
        const indexOutOfView = totalNumFrames ~/ 2;
        expect(
          const Range(0, totalFramesInView).contains(indexOutOfView),
          isFalse,
        );
        framesController.handleSelectedFrame(
          // Select a frame that is out of view (we know from the previous )
          framesController.flutterFrames.value[indexOutOfView],
        );
        expect(framesController.selectedFrame.value, isNotNull);

        await pumpChart(tester);
        expect(find.byType(FramesChart), findsOneWidget);
        expect(
          find.byType(FlutterFramesChartItem),
          findsNWidgets(totalFramesInView),
        );

        verifyScrollOffset(tester, 648.0);
      });
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

    testWidgets(
      'builds with janky frame raster only',
      (WidgetTester tester) async {
        framesController.addFrame(jankyFrameRasterOnly);

        await pumpChart(tester);
        expect(find.byType(FlutterFramesChartItem), findsOneWidget);
        final ui =
            tester.widget(find.byKey(const Key('frame 4 - ui'))) as Container;
        expect(ui.color, equals(mainUiColor));
        final raster = tester.widget(find.byKey(const Key('frame 4 - raster')))
            as Container;
        expect(raster.color, equals(rasterJankColor));
      },
    );

    testWidgets(
      'builds with janky frame with shader jank',
      (WidgetTester tester) async {
        framesController.addFrame(testFrameWithShaderJank);

        await pumpChart(tester);
        expect(find.byType(FlutterFramesChartItem), findsOneWidget);
        final ui =
            tester.widget(find.byKey(const Key('frame 5 - ui'))) as Container;
        expect(ui.color, equals(uiJankColor));
        final raster = tester.widget(find.byKey(const Key('frame 5 - raster')))
            as Container;
        expect(raster.color, equals(rasterJankColor));
        final shaders = tester
            .widget(find.byKey(const Key('frame 5 - shaders'))) as Container;
        expect(shaders.color, equals(shaderCompilationColor.background));
        expect(find.byType(ShaderJankWarningIcon), findsOneWidget);
      },
    );

    testWidgets(
      'builds with janky frame with subtle shader jank',
      (WidgetTester tester) async {
        framesController.addFrame(testFrameWithSubtleShaderJank);

        await pumpChart(tester);
        expect(find.byType(FlutterFramesChartItem), findsOneWidget);
        final ui =
            tester.widget(find.byKey(const Key('frame 6 - ui'))) as Container;
        expect(ui.color, equals(uiJankColor));
        final raster = tester.widget(find.byKey(const Key('frame 6 - raster')))
            as Container;
        expect(raster.color, equals(rasterJankColor));
        final shaders = tester
            .widget(find.byKey(const Key('frame 6 - shaders'))) as Container;
        expect(shaders.color, equals(shaderCompilationColor.background));
        expect(find.byType(ShaderJankWarningIcon), findsNothing);
      },
    );

    testWidgets(
      'can pause and resume frame recording from controls',
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
      },
    );
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
