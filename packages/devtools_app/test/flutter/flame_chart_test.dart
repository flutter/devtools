// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/charts/flutter/flame_chart.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

void main() {
  const zoom = 1.0;

  group('ScrollingFlameChartRow', () {
    ScrollingFlameChartRow currentRow;
    final linkedScrollControllerGroup = LinkedScrollControllerGroup();
    final row = ScrollingFlameChartRow(
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      nodes: testNodes,
      width: 500.0, // 500.0 is arbitrary.
      startInset: sideInset,
      selected: null,
      zoom: FlameChartState.minZoomLevel,
      cacheExtent: null,
    );

    Future<void> pumpScrollingFlameChartRow(
      WidgetTester tester,
      ScrollingFlameChartRow row,
    ) async {
      await tester.pumpWidget(Container(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: currentRow = row,
        ),
      ));
    }

    testWidgets('builds with nodes in row', (WidgetTester tester) async {
      await pumpScrollingFlameChartRow(tester, row);
      expect(find.byWidget(currentRow), findsOneWidget);
      expect(find.byType(MouseRegion), findsOneWidget);

      final sizedBoxFinder = find.byType(SizedBox);
      final SizedBox box = tester.widget(sizedBoxFinder);
      expect(box.height, equals(rowHeightWithPadding));
    });

    testWidgets('builds for empty nodes list', (WidgetTester tester) async {
      final emptyRow = ScrollingFlameChartRow(
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        nodes: const [],
        width: 500.0, // 500.0 is arbitrary.
        startInset: sideInset,
        selected: null,
        zoom: FlameChartState.minZoomLevel,
        cacheExtent: null,
      );

      await pumpScrollingFlameChartRow(tester, emptyRow);
      expect(find.byWidget(currentRow), findsOneWidget);
      expect(find.byType(MouseRegion), findsNothing);

      final sizedBoxFinder = find.byType(SizedBox);
      final SizedBox box = tester.widget(sizedBoxFinder);
      expect(box.height, equals(sectionSpacing));
    });

    testWidgets('binary search for node return correct node',
        (WidgetTester tester) async {
      await pumpScrollingFlameChartRow(tester, row);
      expect(find.byWidget(currentRow), findsOneWidget);
      final ScrollingFlameChartRowState rowState =
          tester.state(find.byWidget(currentRow));

      expect(rowState.binarySearchForNode(-10.0), isNull);
      expect(rowState.binarySearchForNode(49.0), isNull);
      expect(rowState.binarySearchForNode(50.0), equals(testNode2));
      expect(rowState.binarySearchForNode(160.0), equals(testNode3));
      expect(rowState.binarySearchForNode(300.0), equals(testNode4));
      expect(rowState.binarySearchForNode(1000.0), isNull);
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
                  zoom: zoom,
                );
              },
            ),
          ],
        ),
      ));
    }

    testWidgets('builds with correct colors for selected state',
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
    });

    testWidgets('builds with correct colors for non-selected state',
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
    });

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
  });
}

const narrowNodeKey = Key('narrow node');
final narrowNode = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 2',
  tooltip: 'Test node 2 tooltip',
  rect: const Rect.fromLTWH(23.0, 0.0, 21.9, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

const Key testNodeKey = Key('test node');
final testNode = FlameChartNode<TimelineEvent>(
  key: testNodeKey,
  text: 'Test node 1',
  tooltip: 'Test node 1 tooltip',
  // 22.0 is the minimum node width for text.
  rect: const Rect.fromLTWH(0.0, 0.0, 22.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode2 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 2',
  tooltip: 'Test node 2 tooltip',
  rect: const Rect.fromLTWH(50.0, 0.0, 50.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode3 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 3',
  tooltip: 'Test node 3 tooltip',
  rect: const Rect.fromLTWH(110.0, 0.0, 50.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNode4 = FlameChartNode<TimelineEvent>(
  key: narrowNodeKey,
  text: 'Test node 4',
  tooltip: 'Test node 4 tooltip',
  rect: const Rect.fromLTWH(170.0, 0.0, 300.0, rowHeight),
  backgroundColor: Colors.blue,
  textColor: Colors.white,
  data: goldenAsyncTimelineEvent,
  onSelected: (_) {},
);

final testNodes = [
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
