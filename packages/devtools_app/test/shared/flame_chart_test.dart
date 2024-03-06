// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app/src/screens/profiler/panes/cpu_flame_chart.dart';
import 'package:devtools_app/src/shared/charts/flame_chart.dart';
import 'package:devtools_app/src/shared/primitives/flutter_widgets/linked_scroll_controller.dart';
import 'package:devtools_app/src/shared/ui/utils.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/test_data/cpu_profiler/cpu_profile.dart';

void main() {
  const defaultZoom = 1.0;

  setGlobal(IdeTheme, IdeTheme());

  const narrowNodeKey = Key('narrow node');
  final narrowNode = FlameChartNode<CpuStackFrame>(
    key: narrowNodeKey,
    text: 'Narrow test node',
    rect: Rect.fromLTWH(23.0, 0.0, 21.9, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  const Key testNodeKey = Key('test node');
  final testNode = FlameChartNode<CpuStackFrame>(
    key: testNodeKey,
    text: 'Test node 1',
    // 30.0 is the minimum node width for text.
    rect: Rect.fromLTWH(70.0, 0.0, 30.0, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  final testNode2 = FlameChartNode<CpuStackFrame>(
    key: narrowNodeKey,
    text: 'Test node 2',
    rect: Rect.fromLTWH(120.0, 0.0, 50.0, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  final testNode3 = FlameChartNode<CpuStackFrame>(
    key: narrowNodeKey,
    text: 'Test node 3',
    rect: Rect.fromLTWH(180.0, 0.0, 50.0, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  final testNode4 = FlameChartNode<CpuStackFrame>(
    key: narrowNodeKey,
    text: 'Test node 4',
    rect: Rect.fromLTWH(240.0, 0.0, 300.0, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  final testNodes = [
    testNode,
    testNode2,
    testNode3,
    testNode4,
  ];

  const noWidthNodeKey = Key('no-width node');
  final negativeWidthNode = FlameChartNode<CpuStackFrame>(
    key: noWidthNodeKey,
    text: 'No-width node',
    rect: Rect.fromLTWH(1.0, 0.0, -0.1, chartRowHeight),
    colorPair: ThemedColorPair.from(
      const ColorPair(background: Colors.blue, foreground: Colors.white),
    ),
    data: stackFrameA,
    onSelected: (_) {},
  )..sectionIndex = 0;

  group('FlameChart', () {
    // Use an instance of [CpuProfileFlameChart] because the data is simple to
    // stub and [FlameChart] is an abstract class.
    late CpuProfilerController controller;
    late CpuProfileFlameChart flameChart;

    Future<void> pumpFlameChart(WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000.0, 1000.0)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: flameChart,
          ),
        ),
      );
    }

    setUp(() {
      final mockServiceConnection = createMockServiceConnectionWithDefaults();
      final mockServiceManager =
          mockServiceConnection.serviceManager as MockServiceManager;
      setGlobal(ServiceConnectionManager, mockServiceConnection);

      final connectedApp = MockConnectedApp();
      mockConnectedApp(
        connectedApp,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );
      when(mockServiceManager.connectedApp).thenReturn(connectedApp);

      controller = CpuProfilerController();
      flameChart = CpuProfileFlameChart(
        data: CpuProfileData.parse(cpuProfileResponseJson),
        width: 1000.0,
        height: 1000.0,
        selectionNotifier: ValueNotifier<CpuStackFrame?>(null),
        searchMatchesNotifier: controller.searchMatches,
        activeSearchMatchNotifier: controller.activeSearchMatch,
        onDataSelected: (_) {},
      );
    });

    testWidgets(
      'WASD keys zoom and update scroll position',
      (WidgetTester tester) async {
        await pumpFlameChart(tester);
        expect(find.byWidget(flameChart), findsOneWidget);
        final FlameChartState state = tester.state(find.byWidget(flameChart));

        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));
        state.mouseHoverX = 100.0;
        state.focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Use platform macos so that we have access to [event.data.keyLabel].
        // Event simulation is not supported for platform 'web'.

        // Zoom in.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(20.0));

        // Zoom in further.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(2.25));
        expect(state.horizontalControllerGroup.offset, equals(50.0));

        // Zoom out.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(20.0));

        // Zoom out further.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));

        // Zoom out and verify we cannot go beyond the minimum zoom level (1.0);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));

        // Verify that the scroll position does not change when the mouse is
        // positioned in an unzoomable area (start or end inset).
        state.mouseHoverX = 30.0;
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(0.0));
      },
    );

    testWidgets('WASD keys pan chart', (WidgetTester tester) async {
      await pumpFlameChart(tester);
      expect(find.byWidget(flameChart), findsOneWidget);
      final FlameChartState state = tester.state(find.byWidget(flameChart));

      expect(state.zoomController.value, equals(1.0));
      expect(state.horizontalControllerGroup.offset, equals(0.0));
      state.mouseHoverX = 500.0;
      state.focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Use platform macos so that we have access to [event.data.keyLabel].
      // Event simulation is not supported for platform 'web'.

      // Zoom in so we have room to pan around.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(550.0));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(300.0));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(550.0));

      // Zoom in.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(1045.0));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(795.0));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(1045.0));
    });

    testWidgets(
      ',AOE keys zoom and update scroll position',
      (WidgetTester tester) async {
        await pumpFlameChart(tester);
        expect(find.byWidget(flameChart), findsOneWidget);
        final FlameChartState state = tester.state(find.byWidget(flameChart));

        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));
        state.mouseHoverX = 100.0;
        state.focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Use platform macos so that we have access to [event.data.keyLabel].
        // Event simulation is not supported for platform 'web'.

        // Zoom in.
        await tester.sendKeyEvent(
          LogicalKeyboardKey.comma,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyW,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(20.0));

        // Zoom in further.
        await tester.sendKeyEvent(
          LogicalKeyboardKey.comma,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyW,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(2.25));
        expect(state.horizontalControllerGroup.offset, equals(50.0));

        // Zoom out.
        await tester.sendKeyEvent(
          LogicalKeyboardKey.keyO,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyS,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(20.0));

        // Zoom out further.
        await tester.sendKeyEvent(
          LogicalKeyboardKey.keyO,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyS,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));

        // Zoom out and verify we cannot go beyond the minimum zoom level (1.0);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.keyO,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyS,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.0));
        expect(state.horizontalControllerGroup.offset, equals(0.0));

        // Verify that the scroll position does not change when the mouse is
        // positioned in an unzoomable area (start or end inset).
        state.mouseHoverX = 30.0;
        await tester.sendKeyEvent(
          LogicalKeyboardKey.comma,
          platform: 'macos',
          physicalKey: PhysicalKeyboardKey.keyW,
        );
        await tester.pumpAndSettle();
        expect(state.zoomController.value, equals(1.5));
        expect(state.horizontalControllerGroup.offset, equals(0.0));
      },
    );

    testWidgets(',AOE keys pan chart', (WidgetTester tester) async {
      await pumpFlameChart(tester);
      expect(find.byWidget(flameChart), findsOneWidget);
      final FlameChartState state = tester.state(find.byWidget(flameChart));

      expect(state.zoomController.value, equals(1.0));
      expect(state.horizontalControllerGroup.offset, equals(0.0));
      state.mouseHoverX = 500.0;
      state.focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Use platform macos so that we have access to [event.data.keyLabel].
      // Event simulation is not supported for platform 'web'.

      // Zoom in so we have room to pan around.
      await tester.sendKeyEvent(
        LogicalKeyboardKey.comma,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyW,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(
        LogicalKeyboardKey.comma,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyW,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(550.0));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyA,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(300.0));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyE,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.horizontalControllerGroup.offset, equals(550.0));

      // Zoom in.
      await tester.sendKeyEvent(
        LogicalKeyboardKey.comma,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyW,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(1045.0));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyA,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(795.0));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyE,
        platform: 'macos',
        physicalKey: PhysicalKeyboardKey.keyD,
      );
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.horizontalControllerGroup.offset, equals(1045.0));
    });

    group('binary search for node', () {
      testWidgets(
        'returns correct node for default zoom level',
        (WidgetTester tester) async {
          const zoomLevel = 1.0;
          expect(
            binarySearchForNodeHelper(
              x: -10.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 49.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 70.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode,
          );
          expect(
            binarySearchForNodeHelper(
              x: 120.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode2,
          );
          expect(
            binarySearchForNodeHelper(
              x: 230.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode3,
          );
          expect(
            binarySearchForNodeHelper(
              x: 360.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode4,
          );
          expect(
            binarySearchForNodeHelper(
              x: 1060.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
        },
      );

      testWidgets(
        'returns correct node in zoomed row',
        (WidgetTester tester) async {
          const zoomLevel = 2.0;
          expect(
            binarySearchForNodeHelper(
              x: -10.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 49.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 70.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode,
          );
          expect(
            binarySearchForNodeHelper(
              x: 130.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode,
          );
          expect(
            binarySearchForNodeHelper(
              x: 130.1,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 169.9,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 170.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode2,
          );
          expect(
            binarySearchForNodeHelper(
              x: 270.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode2,
          );
          expect(
            binarySearchForNodeHelper(
              x: 270.1,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 289.9,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 290.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode3,
          );
          expect(
            binarySearchForNodeHelper(
              x: 409.9,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 410.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode4,
          );
          expect(
            binarySearchForNodeHelper(
              x: 1010.0,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            testNode4,
          );
          expect(
            binarySearchForNodeHelper(
              x: 1010.1,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
          expect(
            binarySearchForNodeHelper(
              x: 10000,
              nodesInRow: testNodes,
              zoom: zoomLevel,
              startInset: sideInset,
            ),
            isNull,
          );
        },
      );
    });
  });

  group('ScrollingFlameChartRow', () {
    late ScrollingFlameChartRow currentRow;
    final linkedScrollControllerGroup = LinkedScrollControllerGroup();
    final testRow = ScrollingFlameChartRow<CpuStackFrame>(
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      nodes: testNodes,
      width: 680.0, // 680.0 fits all test nodes and sideInsets of 70.0.
      startInset: sideInset,
      hoveredNotifier: ValueNotifier<CpuStackFrame?>(null),
      selectionNotifier: ValueNotifier<CpuStackFrame?>(null),
      searchMatchesNotifier: null,
      activeSearchMatchNotifier: null,
      backgroundColor: Colors.transparent,
      zoom: FlameChart.minZoomLevel,
    );

    Future<void> pumpScrollingFlameChartRow(
      WidgetTester tester,
      ScrollingFlameChartRow row,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  return currentRow = row;
                },
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('builds with nodes in row', (WidgetTester tester) async {
      await pumpScrollingFlameChartRow(tester, testRow);
      expect(find.byWidget(currentRow), findsOneWidget);

      // 1 for row container and 4 for node containers.
      expect(tester.widgetList(find.byType(Container)).length, equals(5));
    });

    testWidgets('builds for empty nodes list', (WidgetTester tester) async {
      final emptyRow = ScrollingFlameChartRow<CpuStackFrame>(
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        nodes: const [],
        width: 500.0, // 500.0 is arbitrary.
        startInset: sideInset,
        hoveredNotifier: ValueNotifier<CpuStackFrame?>(null),
        selectionNotifier: ValueNotifier<CpuStackFrame?>(null),
        searchMatchesNotifier: null,
        activeSearchMatchNotifier: null,
        backgroundColor: Colors.transparent,
        zoom: FlameChart.minZoomLevel,
      );

      await pumpScrollingFlameChartRow(tester, emptyRow);
      expect(find.byWidget(currentRow), findsOneWidget);

      final emptyRowFinder = find.byType(EmptyFlameChartRow);
      final EmptyFlameChartRow emptyFlameChartRow =
          tester.widget(emptyRowFinder);
      expect(emptyFlameChartRow.height, equals(sectionSpacing));
    });
  });

  group('FlameChartNode', () {
    final nodeFinder = find.byKey(testNodeKey);
    final textFinder = find.byType(Text);
    final tooltipFinder = find.byType(Tooltip);

    Future<void> pumpFlameChartNode(
      WidgetTester tester, {
      required bool selected,
      required bool hovered,
      FlameChartNode? node,
      double zoom = defaultZoom,
    }) async {
      node ??= testNode;
      await tester.pumpWidget(
        Builder(
          builder: (context) => Directionality(
            textDirection: TextDirection.ltr,
            child: node!.buildWidget(
              selected: selected,
              searchMatch: false,
              activeSearchMatch: false,
              hovered: hovered,
              zoom: zoom,
              theme: Theme.of(context),
            ),
          ),
        ),
      );
    }

    Future<void> pumpFlameChartNodeWithOverlay(
      WidgetTester tester, {
      required bool selected,
      required bool hovered,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (BuildContext context) {
                  return testNode.buildWidget(
                    selected: selected,
                    searchMatch: false,
                    activeSearchMatch: false,
                    hovered: hovered,
                    zoom: defaultZoom,
                    theme: Theme.of(context),
                  );
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'builds with correct colors for selected state',
      (WidgetTester tester) async {
        await pumpFlameChartNode(tester, selected: true, hovered: false);
        expect(nodeFinder, findsOneWidget);
        final Container nodeWidget = tester.widget(nodeFinder);

        expect(nodeWidget.color, equals(darkColorScheme.primary));

        expect(textFinder, findsOneWidget);
        final Text textWidget = tester.widget(textFinder);
        expect(textWidget.style!.color, equals(Colors.black));
      },
    );

    testWidgets(
      'builds with correct colors for non-selected state',
      (WidgetTester tester) async {
        await pumpFlameChartNode(tester, selected: false, hovered: false);

        expect(nodeFinder, findsOneWidget);
        final Container nodeWidget = tester.widget(nodeFinder);
        expect(nodeWidget.color, equals(Colors.blue));

        expect(textFinder, findsOneWidget);
        final Text textWidget = tester.widget(textFinder);
        expect(textWidget.style!.color, equals(Colors.white));
      },
    );

    testWidgets(
      'builds tooltip for hovered state',
      (WidgetTester tester) async {
        await pumpFlameChartNodeWithOverlay(
          tester,
          selected: false,
          hovered: true,
        );

        expect(nodeFinder, findsOneWidget);
        expect(tooltipFinder, findsOneWidget);
      },
    );

    testWidgets(
      'builds without tooltip for non-hovered state',
      (WidgetTester tester) async {
        await pumpFlameChartNodeWithOverlay(
          tester,
          selected: false,
          hovered: false,
        );

        expect(nodeFinder, findsOneWidget);
        expect(tooltipFinder, findsNothing);
      },
    );

    testWidgets(
      'builds without text for narrow widget',
      (WidgetTester tester) async {
        await pumpFlameChartNode(
          tester,
          node: narrowNode,
          selected: false,
          hovered: false,
        );

        expect(find.byKey(narrowNodeKey), findsOneWidget);
        expect(textFinder, findsNothing);
      },
    );

    testWidgets('normalizes negative widths', (WidgetTester tester) async {
      /*
       * This test simulates a node created with a very small width with
       * added padding.
       *
       * We sometimes create empty space between nodes by subtracting some
       * space from the width. We want the node to normalize itself to prevent
       * negative bounds.
       */
      await pumpFlameChartNode(
        tester,
        node: negativeWidthNode,
        selected: false,
        hovered: false,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with zoom', (WidgetTester tester) async {
      await pumpFlameChartNode(
        tester,
        selected: false,
        hovered: false,
        zoom: 2.0,
      );
      expect(nodeFinder, findsOneWidget);
      Container nodeWidget = tester.widget(nodeFinder);
      expect(nodeWidget.constraints!.maxWidth, equals(60.0));

      await pumpFlameChartNode(
        tester,
        selected: false,
        hovered: false,
        zoom: 2.5,
      );
      expect(nodeFinder, findsOneWidget);
      nodeWidget = tester.widget(nodeFinder);
      expect(nodeWidget.constraints!.maxWidth, equals(75.0));
    });
  });

  group('NodeListExtension', () {
    test(
      'toPaddedZoomedIntervals calculation is accurate for unzoomed row',
      () {
        final paddedZoomedIntervals = testNodes.toPaddedZoomedIntervals(
          zoom: 1.0,
          chartStartInset: sideInset,
          chartWidth: 610.0,
        );
        expect(paddedZoomedIntervals[0], equals(const Range(0.0, 120.0)));
        expect(paddedZoomedIntervals[1], equals(const Range(120.0, 180.0)));
        expect(paddedZoomedIntervals[2], equals(const Range(180.0, 240.0)));
        expect(
          paddedZoomedIntervals[3],
          equals(const Range(240.0, 1000000000540.0)),
        );
      },
    );

    test('toPaddedZoomedIntervals calculation is accurate for zoomed row', () {
      final paddedZoomedIntervals = testNodes.toPaddedZoomedIntervals(
        zoom: 2.0,
        chartStartInset: sideInset,
        chartWidth: 1080.0,
      );
      expect(paddedZoomedIntervals[0], equals(const Range(0.0, 170.0)));
      expect(paddedZoomedIntervals[1], equals(const Range(170.0, 290.0)));
      expect(paddedZoomedIntervals[2], equals(const Range(290.0, 410.0)));
      expect(
        paddedZoomedIntervals[3],
        equals(const Range(410.0, 1000000001010.0)),
      );
    });
  });

  group('FlameChartUtils', () {
    test('leftPaddingForNode returns correct value for un-zoomed row', () {
      expect(
        FlameChartUtils.leftPaddingForNode(
          0,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
        ),
        equals(70.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          1,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          2,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          3,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
    });

    test('rightPaddingForNode returns correct value for un-zoomed row', () {
      expect(
        FlameChartUtils.rightPaddingForNode(
          0,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
          chartWidth: 610.0,
        ),
        equals(20.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          1,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
          chartWidth: 610.0,
        ),
        equals(10.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          2,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
          chartWidth: 610.0,
        ),
        equals(10.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          3,
          testNodes,
          chartZoom: 1.0,
          chartStartInset: sideInset,
          chartWidth: 610.0,
        ),
        equals(1000000000000.0),
      );
    });

    test('leftPaddingForNode returns correct value for zoomed row', () {
      expect(
        FlameChartUtils.leftPaddingForNode(
          0,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
        ),
        equals(70.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          1,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          2,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
      expect(
        FlameChartUtils.leftPaddingForNode(
          3,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
        ),
        equals(0.0),
      );
    });

    test('rightPaddingForNode returns correct value for zoomed row', () {
      expect(
        FlameChartUtils.rightPaddingForNode(
          0,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
          chartWidth: 1080.0,
        ),
        equals(40.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          1,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
          chartWidth: 1080.0,
        ),
        equals(20.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          2,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
          chartWidth: 1080.0,
        ),
        equals(20.0),
      );
      expect(
        FlameChartUtils.rightPaddingForNode(
          3,
          testNodes,
          chartZoom: 2.0,
          chartStartInset: sideInset,
          chartWidth: 1080.0,
        ),
        equals(1000000000000.0),
      );
    });

    test('zoomForNode returns correct values', () {
      expect(FlameChartUtils.zoomForNode(testNode, 3.0), equals(3.0));
      expect(FlameChartUtils.zoomForNode(testNode4, 10.0), equals(10.0));
    });
  });
}
