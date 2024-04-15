// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  // Note: tester by default has a window size of 800x600.
  group('Split', () {
    group('builds horizontal layout', () {
      testWidgets('with 25% space to first child', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          initialFractions: [0.25, 0.75],
        );
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_k1), findsOneWidget);
        expect(find.byKey(_k2), findsOneWidget);
        expect(find.byKey(split.dividerKey(0)), findsOneWidget);
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(197.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(591.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(12, 600),
        );
      });

      testWidgets('with 50% space to first child', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          initialFractions: [0.5, 0.5],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(394, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(394, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(12, 600),
        );
      });

      testWidgets('with 75% space to first child', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          initialFractions: [0.75, 0.25],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(591.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(197.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(12, 600),
        );
      });

      testWidgets('with 0% space to first child', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.horizontal, initialFractions: [0.0, 1.0]);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_k1), findsOneWidget);
        expect(find.byKey(_k2), findsOneWidget);
        expect(find.byKey(split.dividerKey(0)), findsOneWidget);
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(788, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(12, 600),
        );
      });

      testWidgets(
        'with 100% space to first child',
        (WidgetTester tester) async {
          final split = buildSplitPane(
            Axis.horizontal,
            initialFractions: [1.0, 0.0],
          );
          await tester.pumpWidget(wrap(split));
          expect(find.byKey(_k1), findsOneWidget);
          expect(find.byKey(_k2), findsOneWidget);
          expect(find.byKey(split.dividerKey(0)), findsOneWidget);
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(788, 600),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(0, 600),
          );
          expectEqualSizes(
            tester.element(find.byKey(split.dividerKey(0))).size!,
            const Size(12, 600),
          );
        },
      );

      testWidgets('with n children', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          children: [_w1, _w2, _w3],
          initialFractions: [0.2, 0.4, 0.4],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(155.2, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(310.4, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );
      });

      testWidgets('with custom splitters', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          children: [_w1, _w2, _w3],
          initialFractions: [0.2, 0.4, 0.4],
          splitters: [_mediumSplitter, _largeSplitter],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(148, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(296, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(296, 600),
        );
      });

      testWidgets(
        'with initialFraction rounding errors',
        (WidgetTester tester) async {
          const oneThird = 0.333333;
          final split = buildSplitPane(
            Axis.horizontal,
            children: [_w1, _w2, _w3],
            initialFractions: [oneThird, oneThird, oneThird],
          );
          await tester.pumpWidget(wrap(split));
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(258.666416, 600),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(258.666416, 600),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(258.666416, 600),
          );
        },
      );
    });

    group('builds vertical layout', () {
      testWidgets('with 25% space to first child', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.25, 0.75]);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_k1), findsOneWidget);
        expect(find.byKey(_k2), findsOneWidget);
        expect(find.byKey(split.dividerKey(0)), findsOneWidget);
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 147),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 441),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(800, 12),
        );
      });

      testWidgets('with 50% space to first child', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.5, 0.5]);
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 294),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 294),
        );
      });

      testWidgets('with 75% space to first child', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.75, 0.25]);
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 441.0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 147.0),
        );
      });

      testWidgets('with 0% space to first child', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.0, 1.0]);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_k1), findsOneWidget);
        expect(find.byKey(_k2), findsOneWidget);
        expect(find.byKey(split.dividerKey(0)), findsOneWidget);
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 588),
        );
        expectEqualSizes(
          tester.element(find.byKey(split.dividerKey(0))).size!,
          const Size(800, 12),
        );
      });

      testWidgets(
        'with 100% space to first child',
        (WidgetTester tester) async {
          final split =
              buildSplitPane(Axis.vertical, initialFractions: [1.0, 0.0]);
          await tester.pumpWidget(wrap(split));
          expect(find.byKey(_k1), findsOneWidget);
          expect(find.byKey(_k2), findsOneWidget);
          expect(find.byKey(split.dividerKey(0)), findsOneWidget);
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(800, 588),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(800, 0),
          );
          expectEqualSizes(
            tester.element(find.byKey(split.dividerKey(0))).size!,
            const Size(800, 12),
          );
        },
      );

      testWidgets('with n children', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.vertical,
          children: [_w1, _w2, _w3],
          initialFractions: [0.2, 0.4, 0.4],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 115.2),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 230.4),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(800, 230.4),
        );
      });

      testWidgets('with custom splitters', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.vertical,
          children: [_w1, _w2, _w3],
          initialFractions: [0.2, 0.4, 0.4],
          splitters: [_mediumSplitter, _largeSplitter],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 108),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 216),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(800, 216),
        );
      });

      testWidgets(
        'with initialFraction rounding errors',
        (WidgetTester tester) async {
          const oneThird = 0.333333;
          final split = buildSplitPane(
            Axis.vertical,
            children: [_w1, _w2, _w3],
            initialFractions: [oneThird, oneThird, oneThird],
          );
          await tester.pumpWidget(wrap(split));
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(800, 191.99981599999998),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(800, 191.99981599999998),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(800, 191.99981599999998),
          );
        },
      );
    });

    group('drags properly', () {
      testWidgets('with horizontal layout', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.horizontal, initialFractions: [0.5, 0.5]);
        await tester.pumpWidget(wrap(split));

        // We start at 0.5 size.
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(394.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(394.0, 600),
        );

        // Drag to 0.75 first child size.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(591.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(197.0, 600),
        );

        // Drag to 0.25 first child size.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-400, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(197.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(591.0, 600),
        );

        // Drag past the right end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(600, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(788, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(0, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(788, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(0, 600),
        );

        // Drag back past the left end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-800, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(788, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(788, 600),
        );
      });

      testWidgets('with vertical layout', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.5, 0.5]);
        await tester.pumpWidget(wrap(split));

        // We start at 0.5 size.
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 294.0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 294.0),
        );

        // Drag to 0.75 first child size.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, 150),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 441.0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 147.0),
        );

        // Drag to 0.25 first child size.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 147.0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 441.0),
        );

        // Drag past the right end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, 450),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 588),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 0),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, 200),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 588),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 0),
        );

        // Drag back past the left end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 588),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(800, 0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(800, 588),
        );
      });

      testWidgets('with n children', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          children: [_w1, _w2, _w3],
          initialFractions: [0.2, 0.4, 0.4],
        );
        await tester.pumpWidget(wrap(split));

        // We start at initial size.
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(155.2, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(310.4, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );

        // Drag first splitter to 0.1 first child size.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-80, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(77.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(388.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );

        // Drag first splitter to the left end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-80, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(465.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(465.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );

        // Drag first splitter to second splitter.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(480, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(465.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(310.4, 600),
        );

        // Drag second splitter past first splitter.
        await tester.drag(
          find.byKey(split.dividerKey(1)),
          const Offset(-100, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(368.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(407.4, 600),
        );

        // Drag second splitter to the right end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(1)),
          const Offset(420, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(368.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(407.4, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(0, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(1)),
          const Offset(200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(368.6, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(407.4, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k3)).size!,
          const Size(0, 600),
        );
      });

      testWidgets('with minSizes', (WidgetTester tester) async {
        final split = buildSplitPane(
          Axis.horizontal,
          initialFractions: [0.5, 0.5],
          minSizes: [100.0, 100.0],
        );
        await tester.pumpWidget(wrap(split));
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(394.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(394.0, 600),
        );

        // Drag splitter to the left end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(100, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(688.0, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(100, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(688.0, 600),
        );

        // Drag splitter to the right end of the widget.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(597.5, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(688.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(100, 600),
        );

        // Make sure we can't overdrag.
        await tester.drag(
          find.byKey(split.dividerKey(0)),
          const Offset(200, 0),
        );
        await tester.pumpAndSettle();
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(688.0, 600),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(100, 600),
        );
      });
    });

    group('resizes contents', () {
      testWidgets('in a horizontal layout', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.horizontal, initialFractions: [0.0, 1.0]);
        await tester.pumpWidget(
          wrap(
            Center(
              child: SizedBox(width: 300.0, height: 300.0, child: split),
            ),
          ),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 300),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(288, 300),
        );

        await tester.pumpWidget(
          wrap(
            Center(
              child: SizedBox(width: 200.0, height: 200.0, child: split),
            ),
          ),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(0, 200),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(188, 200),
        );
      });

      testWidgets(
        'in a horizontal layout with n children',
        (WidgetTester tester) async {
          final split = buildSplitPane(
            Axis.horizontal,
            children: [_w1, _w2, _w3],
            initialFractions: [0.2, 0.4, 0.4],
          );
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(75.2, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(150.4, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(150.4, 400),
          );

          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 200.0, height: 200.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(35.2, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(70.4, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(70.4, 200),
          );
        },
      );

      testWidgets(
        'with violated minsize constraints',
        (WidgetTester tester) async {
          final split = buildSplitPane(
            Axis.horizontal,
            children: [_w1, _w2, _w3],
            initialFractions: [0.1, 0.7, 0.2],
            minSizes: [100.0, 0, 100.0],
          );
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(100, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(176.0, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(100, 400),
          );

          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 230.0, height: 200.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(100.0, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(6.0, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(100.0, 200),
          );

          // It would be nice if we restored the size of w2 in this case but the
          // logic is simpler if we don't as this way the layout calculation can
          // avoid tracking state about what the previous fractions were before
          // clipping which would add more complexity and shouldn't really matter.
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          // TODO(dantup): These now fail, as the results are 100/176/100. It's not
          // clear why these expectations are different to the above when it's
          // in the same size box?
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(182.5242718446602, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(10.951456310679607, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(182.5242718446602, 400),
          );
        },
      );

      testWidgets(
        'with impossible minsize constraints',
        (WidgetTester tester) async {
          final split = buildSplitPane(
            Axis.horizontal,
            children: [_w1, _w2, _w3],
            initialFractions: [0.2, 0.4, 0.4],
            minSizes: [200.0, 0, 400.0],
          );
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(125.33333333333333, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(0, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(250.66666666666666, 400),
          );

          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 200.0, height: 200.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(58.666666666666664, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(0, 200),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(117.33333333333333, 200),
          );

          // Min size constraints still violated but not violated by as much.
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(125.33333333333333, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(0, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(250.66666666666666, 400),
          );

          // Min size constraints are now satisfied.
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 800.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(258.66666666666666, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(0, 400),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(517.3333333333333, 400),
          );
        },
      );

      testWidgets('in a vertical layout', (WidgetTester tester) async {
        final split =
            buildSplitPane(Axis.vertical, initialFractions: [0.0, 1.0]);
        await tester.pumpWidget(
          wrap(
            Center(
              child: SizedBox(width: 300.0, height: 300.0, child: split),
            ),
          ),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(300, 0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(300, 288.0),
        );

        await tester.pumpWidget(
          wrap(
            Center(
              child: SizedBox(width: 200.0, height: 200.0, child: split),
            ),
          ),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k1)).size!,
          const Size(200, 0),
        );
        expectEqualSizes(
          tester.element(find.byKey(_k2)).size!,
          const Size(200, 188),
        );
      });

      testWidgets(
        'in a vertical layout with n children',
        (WidgetTester tester) async {
          final split = buildSplitPane(
            Axis.vertical,
            children: [_w1, _w2, _w3],
            initialFractions: [0.2, 0.4, 0.4],
          );
          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 400.0, height: 400.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(400, 75.2),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(400, 150.4),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(400, 150.4),
          );

          await tester.pumpWidget(
            wrap(
              Center(
                child: SizedBox(width: 200.0, height: 200.0, child: split),
              ),
            ),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k1)).size!,
            const Size(200, 35.2),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k2)).size!,
            const Size(200, 70.4),
          );
          expectEqualSizes(
            tester.element(find.byKey(_k3)).size!,
            const Size(200, 70.4),
          );
        },
      );
    });

    group('axisFor', () {
      testWidgetsWithWindowSize(
        'return Axis.horizontal',
        const Size(800, 800),
        (WidgetTester tester) async {
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) {
                  expectLater(SplitPane.axisFor(context, 1.0), Axis.horizontal);
                  return Container();
                },
              ),
            ),
          );
        },
      );
      testWidgetsWithWindowSize(
        'return Axis.vertical',
        const Size(500, 800),
        (WidgetTester tester) async {
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) {
                  expectLater(SplitPane.axisFor(context, 1.0), Axis.vertical);
                  return Container();
                },
              ),
            ),
          );
        },
      );
    });
  });
}

const _k1 = Key('child 1');
const _k2 = Key('child 2');
const _k3 = Key('child 3');
const _w1 = Text('content1', key: _k1);
const _w2 = Text('content2', key: _k2);
const _w3 = Text('content3', key: _k3);
const _mediumSplitter = PreferredSize(
  preferredSize: Size(20, 20),
  child: SizedBox(height: 20, width: 20),
);
const _largeSplitter = PreferredSize(
  preferredSize: Size(40, 40),
  child: SizedBox(height: 40, width: 40),
);

SplitPane buildSplitPane(
  Axis axis, {
  required List<double> initialFractions,
  List<Widget>? children,
  List<double>? minSizes,
  List<PreferredSizeWidget>? splitters,
}) {
  children ??= const [_w1, _w2];
  return SplitPane(
    axis: axis,
    initialFractions: initialFractions,
    minSizes: minSizes,
    splitters: splitters,
    children: children,
  );
}

void expectEqualSizes(Size a, Size b) {
  expect(
    (a.width - b.width).abs() < defaultEpsilon,
    isTrue,
    reason: 'Widths unequal:\nExpected ${b.width}\nActual: ${a.width}',
  );
  expect(
    (a.height - b.height).abs() < defaultEpsilon,
    isTrue,
    reason: 'Heights unequal:\nExpected ${b.height}\nActual: ${a.height}',
  );
}
