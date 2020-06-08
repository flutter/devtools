// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/flutter_widgets/linked_scroll_controller.dart';
import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/profiler/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaultZoom = 1.0;

  group('FlameChart', () {
    // Use an instance of [CpuProfileFlameChart] because the data is simple to
    // stub and [FlameChart] is an abstract class.
    final flameChart = CpuProfileFlameChart(
      CpuProfileData.parse(cpuProfileResponseJson),
      width: 1000.0,
      selected: null,
      onSelected: (_) {},
    );

    Future<void> pumpFlameChart(WidgetTester tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: flameChart,
      ));
    }

    testWidgets('WASD keys zoom and update scroll position',
        (WidgetTester tester) async {
      await pumpFlameChart(tester);
      expect(find.byWidget(flameChart), findsOneWidget);
      final FlameChartState state = tester.state(find.byWidget(flameChart));

      expect(state.zoomController.value, equals(1.0));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(0.0));
      state.mouseHoverX = 100.0;
      state.focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Use platform macos so that we have access to [event.data.keyLabel].
      // Event simulation is not supported for platform 'web'.

      // Zoom in.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(1.5));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(30.0));

      // Zoom in further.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(75.0));

      // Zoom out.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(1.5));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(30.0));

      // Zoom out further.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(1.0));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(0.0));

      // Zoom out and verify we cannot go beyond the minimum zoom level (1.0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(1.0));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(0.0));

      // Verify that the scroll position does not change when the mouse is
      // positioned in an unzoomable area (start or end inset).
      state.mouseHoverX = 30.0;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(1.5));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(0.0));
    });

    testWidgets('WASD keys pan chart', (WidgetTester tester) async {
      await pumpFlameChart(tester);
      expect(find.byWidget(flameChart), findsOneWidget);
      final FlameChartState state = tester.state(find.byWidget(flameChart));

      expect(state.zoomController.value, equals(1.0));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(0.0));
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
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(575.0));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(325.0));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(2.25));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(575.0));

      // Zoom in.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(
          state.linkedHorizontalScrollControllerGroup.offset, equals(1092.5));

      // Pan left. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(state.linkedHorizontalScrollControllerGroup.offset, equals(842.5));

      // Pan right. Pan unit should equal 1/4th of the original width (1000.0).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, platform: 'macos');
      await tester.pumpAndSettle();
      expect(state.zoomController.value, equals(3.375));
      expect(
          state.linkedHorizontalScrollControllerGroup.offset, equals(1092.5));
    });
  });

  group('ScrollingFlameChartRow', () {
    ScrollingFlameChartRow currentRow;
    final linkedScrollControllerGroup = LinkedScrollControllerGroup();
    final testRow = ScrollingFlameChartRow(
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      nodes: testNodesWithLabel,
      width: 610.0, // 610.0 fits all test nodes and sideInsets of 70.0.
      startInset: sideInset,
      selected: null,
      zoom: FlameChart.minZoomLevel,
    );
    final zoomedTestRow = ScrollingFlameChartRow(
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      nodes: testNodesWithLabel,
      // 1080.0 fits all test nodes at zoom level 2.0 and sideInsets of 70.0.
      width: 1080.0,
      startInset: sideInset,
      selected: null,
      zoom: 2.0,
    );

    Future<void> pumpScrollingFlameChartRow(
      WidgetTester tester,
      ScrollingFlameChartRow row,
    ) async {
      await tester.pumpWidget(Directionality(
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
      ));
    }

    Future<ScrollingFlameChartRowState> pumpRowAndGetState(
      WidgetTester tester, {
      ScrollingFlameChartRow row,
    }) async {
      row ??= testRow;
      await pumpScrollingFlameChartRow(tester, row);
      expect(find.byWidget(currentRow), findsOneWidget);
      return tester.state(find.byWidget(currentRow));
    }

    testWidgets('builds with nodes in row', (WidgetTester tester) async {
      await pumpScrollingFlameChartRow(tester, testRow);
      expect(find.byWidget(currentRow), findsOneWidget);
      expect(find.byType(MouseRegion), findsOneWidget);

      final sizedBoxFinder = find.byType(SizedBox);
      final SizedBox box = tester.firstWidget(sizedBoxFinder);
      expect(box.height, equals(rowHeightWithPadding));
    });

    testWidgets('builds for empty nodes list', (WidgetTester tester) async {
      final emptyRow = ScrollingFlameChartRow(
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        nodes: const [],
        width: 500.0, // 500.0 is arbitrary.
        startInset: sideInset,
        selected: null,
        zoom: FlameChart.minZoomLevel,
      );

      await pumpScrollingFlameChartRow(tester, emptyRow);
      expect(find.byWidget(currentRow), findsOneWidget);
      expect(find.byType(MouseRegion), findsNothing);

      final sizedBoxFinder = find.byType(SizedBox);
      final SizedBox box = tester.widget(sizedBoxFinder);
      expect(box.height, equals(sectionSpacing));
    });

    testWidgets('binary search for node returns correct node',
        (WidgetTester tester) async {
      final rowState = await pumpRowAndGetState(tester);
      expect(rowState.binarySearchForNode(-10.0), isNull);
      expect(rowState.binarySearchForNode(10.0), equals(labelNode));
      expect(rowState.binarySearchForNode(49.0), isNull);
      expect(rowState.binarySearchForNode(70.0), equals(testNode));
      expect(rowState.binarySearchForNode(120.0), equals(testNode2));
      expect(rowState.binarySearchForNode(230.0), equals(testNode3));
      expect(rowState.binarySearchForNode(360.0), equals(testNode4));
      expect(rowState.binarySearchForNode(1060.0), isNull);
    });

    testWidgets('binary search for node returns correct node in zoomed row',
        (WidgetTester tester) async {
      final rowState = await pumpRowAndGetState(tester, row: zoomedTestRow);
      expect(rowState.binarySearchForNode(-10.0), isNull);
      expect(rowState.binarySearchForNode(10.0), equals(labelNode));
      expect(rowState.binarySearchForNode(49.0), isNull);
      expect(rowState.binarySearchForNode(70.0), equals(testNode));
      expect(rowState.binarySearchForNode(114.0), equals(testNode));
      expect(rowState.binarySearchForNode(114.1), isNull);
      expect(rowState.binarySearchForNode(169.9), isNull);
      expect(rowState.binarySearchForNode(170.0), equals(testNode2));
      expect(rowState.binarySearchForNode(270.0), equals(testNode2));
      expect(rowState.binarySearchForNode(270.1), isNull);
      expect(rowState.binarySearchForNode(289.9), isNull);
      expect(rowState.binarySearchForNode(290.0), equals(testNode3));
      expect(rowState.binarySearchForNode(409.9), isNull);
      expect(rowState.binarySearchForNode(410.0), equals(testNode4));
      expect(rowState.binarySearchForNode(1010.0), equals(testNode4));
      expect(rowState.binarySearchForNode(1010.1), isNull);
      expect(rowState.binarySearchForNode(10000), isNull);
    });
  });

  group('FlameChartNode', () {
    final nodeFinder = find.byKey(testNodeKey);
    final textFinder = find.byType(Text);
    final tooltipFinder = find.byType(Tooltip);

    Future<void> pumpFlameChartNode(
      WidgetTester tester, {
      @required bool selected,
      @required bool hovered,
      FlameChartNode node,
      double zoom = defaultZoom,
    }) async {
      node ??= testNode;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: node.buildWidget(
          selected: selected,
          hovered: hovered,
          zoom: zoom,
        ),
      ));
    }

    Future<void> pumpFlameChartNodeWithOverlay(
      WidgetTester tester, {
      @required bool selected,
      @required bool hovered,
    }) async {
      final _selected = selected;
      final _hovered = hovered;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (BuildContext context) {
                return testNode.buildWidget(
                  selected: _selected,
                  hovered: _hovered,
                  zoom: defaultZoom,
                );
              },
            ),
          ],
        ),
      ));
    }

    testWidgets(
      'builds with correct colors for selected state',
      (WidgetTester tester) async {
        await pumpFlameChartNode(tester, selected: true, hovered: false);
        expect(nodeFinder, findsOneWidget);
        final Container nodeWidget = tester.widget(nodeFinder);
        expect(
          (nodeWidget.decoration as BoxDecoration).color,
          equals(mainUiColorSelectedLight),
        );

        expect(textFinder, findsOneWidget);
        final Text textWidget = tester.widget(textFinder);
        expect(textWidget.style.color, equals(Colors.black));
      },
      skip: true,
    );

    testWidgets(
      'builds with correct colors for non-selected state',
      (WidgetTester tester) async {
        await pumpFlameChartNode(tester, selected: false, hovered: false);

        expect(nodeFinder, findsOneWidget);
        final Container nodeWidget = tester.widget(nodeFinder);
        expect(
          (nodeWidget.decoration as BoxDecoration).color,
          equals(Colors.blue),
        );

        expect(textFinder, findsOneWidget);
        final Text textWidget = tester.widget(textFinder);
        expect(textWidget.style.color, equals(Colors.white));
      },
      skip: true,
    );

    testWidgets('builds tooltip for hovered state',
        (WidgetTester tester) async {
      await pumpFlameChartNodeWithOverlay(
        tester,
        selected: false,
        hovered: true,
      );

      expect(nodeFinder, findsOneWidget);
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('builds without tooltip for non-hovered state',
        (WidgetTester tester) async {
      await pumpFlameChartNodeWithOverlay(
        tester,
        selected: false,
        hovered: false,
      );

      expect(nodeFinder, findsOneWidget);
      expect(tooltipFinder, findsNothing);
    });

    testWidgets('builds without text for narrow widget',
        (WidgetTester tester) async {
      await pumpFlameChartNode(
        tester,
        node: narrowNode,
        selected: false,
        hovered: false,
      );

      expect(find.byKey(narrowNodeKey), findsOneWidget);
      expect(textFinder, findsNothing);
    });

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
      expect(nodeWidget.constraints.maxWidth, equals(44.0));

      await pumpFlameChartNode(
        tester,
        selected: false,
        hovered: false,
        zoom: 2.5,
      );
      expect(nodeFinder, findsOneWidget);
      nodeWidget = tester.widget(nodeFinder);
      expect(nodeWidget.constraints.maxWidth, equals(55.0));
    });
  });

  group('NodeListExtension', () {
    test(
        'toPaddedZoomedIntervals calculation is accurate for unzoomed row with'
        ' label', () {
      final paddedZoomedIntervals = testNodesWithLabel.toPaddedZoomedIntervals(
        zoom: 1.0,
        chartStartInset: sideInset,
        chartWidth: 610.0,
      );
      expect(paddedZoomedIntervals[0], equals(const Range(0.0, 70.0)));
      expect(paddedZoomedIntervals[1], equals(const Range(70.0, 120.0)));
      expect(paddedZoomedIntervals[2], equals(const Range(120.0, 180.0)));
      expect(paddedZoomedIntervals[3], equals(const Range(180.0, 240.0)));
      expect(paddedZoomedIntervals[4], equals(const Range(240.0, 1000540.0)));
    });

    test(
        'toPaddedZoomedIntervals calculation is accurate for unzoomed row '
        'without label', () {
      final paddedZoomedIntervals =
          testNodesWithoutLabel.toPaddedZoomedIntervals(
        zoom: 1.0,
        chartStartInset: sideInset,
        chartWidth: 610.0,
      );
      expect(paddedZoomedIntervals[0], equals(const Range(0.0, 120.0)));
      expect(paddedZoomedIntervals[1], equals(const Range(120.0, 180.0)));
      expect(paddedZoomedIntervals[2], equals(const Range(180.0, 240.0)));
      expect(paddedZoomedIntervals[3], equals(const Range(240.0, 1000540.0)));
    });

    test(
        'toPaddedZoomedIntervals calculation is accurate for zoomed row with '
        'label', () {
      final paddedZoomedIntervals = testNodesWithLabel.toPaddedZoomedIntervals(
        zoom: 2.0,
        chartStartInset: sideInset,
        chartWidth: 1080.0,
      );
      expect(paddedZoomedIntervals[0], equals(const Range(0.0, 70.0)));
      expect(paddedZoomedIntervals[1], equals(const Range(70.0, 170.0)));
      expect(paddedZoomedIntervals[2], equals(const Range(170.0, 290.0)));
      expect(paddedZoomedIntervals[3], equals(const Range(290.0, 410.0)));
      expect(paddedZoomedIntervals[4], equals(const Range(410.0, 1001010.0)));
    });

    test(
        'toPaddedZoomedIntervals calculation is accurate for zoomed row without'
        ' label', () {
      final paddedZoomedIntervals =
          testNodesWithoutLabel.toPaddedZoomedIntervals(
        zoom: 2.0,
        chartStartInset: sideInset,
        chartWidth: 1080.0,
      );
      expect(paddedZoomedIntervals[0], equals(const Range(0.0, 170.0)));
      expect(paddedZoomedIntervals[1], equals(const Range(170.0, 290.0)));
      expect(paddedZoomedIntervals[2], equals(const Range(290.0, 410.0)));
      expect(paddedZoomedIntervals[3], equals(const Range(410.0, 1001010.0)));
    });
  });

  group('FlameChartUtils', () {
    test('leftPaddingForNode returns correct value for un-zoomed row', () {
      // Row with label.
      expect(
          FlameChartUtils.leftPaddingForNode(0, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(2.0));
      expect(
          FlameChartUtils.leftPaddingForNode(1, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(2, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(3, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(4, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));

      // Row without label.
      expect(
          FlameChartUtils.leftPaddingForNode(0, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(70.0));
      expect(
          FlameChartUtils.leftPaddingForNode(1, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(2, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(3, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset),
          equals(0.0));
    });

    test('rightPaddingForNode returns correct value for un-zoomed row', () {
      // Row with label.
      expect(
          FlameChartUtils.rightPaddingForNode(0, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(48.0));
      expect(
          FlameChartUtils.rightPaddingForNode(1, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(28.0));
      expect(
          FlameChartUtils.rightPaddingForNode(2, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(10.0));
      expect(
          FlameChartUtils.rightPaddingForNode(3, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(10.0));
      expect(
          FlameChartUtils.rightPaddingForNode(4, testNodesWithLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(1000000.0));

      // Row without label.
      expect(
          FlameChartUtils.rightPaddingForNode(0, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(28.0));
      expect(
          FlameChartUtils.rightPaddingForNode(1, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(10.0));
      expect(
          FlameChartUtils.rightPaddingForNode(2, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(10.0));
      expect(
          FlameChartUtils.rightPaddingForNode(3, testNodesWithoutLabel,
              chartZoom: 1.0, chartStartInset: sideInset, chartWidth: 610.0),
          equals(1000000.0));
    });

    test('leftPaddingForNode returns correct value for zoomed row', () {
      expect(
          FlameChartUtils.leftPaddingForNode(0, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset),
          equals(2.0));
      expect(
          FlameChartUtils.leftPaddingForNode(1, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(2, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(3, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset),
          equals(0.0));
      expect(
          FlameChartUtils.leftPaddingForNode(4, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset),
          equals(0.0));
    });

    test('rightPaddingForNode returns correct value for zoomed row', () {
      expect(
          FlameChartUtils.rightPaddingForNode(0, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset, chartWidth: 1080.0),
          equals(48.0));
      expect(
          FlameChartUtils.rightPaddingForNode(1, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset, chartWidth: 1080.0),
          equals(56.0));
      expect(
          FlameChartUtils.rightPaddingForNode(2, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset, chartWidth: 1080.0),
          equals(20.0));
      expect(
          FlameChartUtils.rightPaddingForNode(3, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset, chartWidth: 1080.0),
          equals(20.0));
      expect(
          FlameChartUtils.rightPaddingForNode(4, testNodesWithLabel,
              chartZoom: 2.0, chartStartInset: sideInset, chartWidth: 1080.0),
          equals(1000000.0));
    });

    test('zoomForNode returns correct values', () {
      expect(FlameChartUtils.zoomForNode(labelNode, 2.0), equals(1.0));
      expect(FlameChartUtils.zoomForNode(testNode, 3.0), equals(3.0));
      expect(FlameChartUtils.zoomForNode(testNode4, 10.0), equals(10.0));
    });
  });
}

const narrowNodeKey = Key('narrow node');
final narrowNode = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Narrow test node',
  tooltip: 'Narrow test node tooltip',
  rect: const Rect.fromLTWH(23.0, 0.0, 21.9, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

const labelNodeKey = Key('label node');
final labelNode = FlameChartNode<TimelineEvent>(
  key: labelNodeKey,
  text: 'label test node',
  tooltip: 'label test node',
  // 22.0 is the minimum node width for text.
  rect: const Rect.fromLTWH(2.0, 0.0, 20.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  selectable: false,
  onSelected: (_) {},
);

const Key testNodeKey = Key('test node');
final testNode = FlameChartNode<TimelineEvent>(
  key: testNodeKey,
  text: 'Test node 1',
  tooltip: 'Test node 1 tooltip',
  // 22.0 is the minimum node width for text.
  rect: const Rect.fromLTWH(70.0, 0.0, 22.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode2 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 2',
  tooltip: 'Test node 2 tooltip',
  rect: const Rect.fromLTWH(120.0, 0.0, 50.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode3 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 3',
  tooltip: 'Test node 3 tooltip',
  rect: const Rect.fromLTWH(180.0, 0.0, 50.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode4 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 4',
  tooltip: 'Test node 4 tooltip',
  rect: const Rect.fromLTWH(240.0, 0.0, 300.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNodesWithLabel = [
  labelNode,
  testNode,
  testNode2,
  testNode3,
  testNode4,
];

final testNodesWithoutLabel = [
  testNode,
  testNode2,
  testNode3,
  testNode4,
];

const noWidthNodeKey = Key('no-width node');
final negativeWidthNode = FlameChartNode<TimelineEvent>(
  key: noWidthNodeKey,
  text: 'No-width node',
  tooltip: 'no-width node tooltip',
  rect: const Rect.fromLTWH(1.0, 0.0, -0.1, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);
