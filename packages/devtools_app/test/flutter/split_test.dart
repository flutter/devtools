// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  // Note: tester by default has a window size of 800x600.
  group('Split', () {
    group('builds horizontal layout', () {
      testWidgets('with 25% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.25);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(195, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(595, 600));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(10, 600));
      });

      testWidgets('with 50% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.50);
        await tester.pumpWidget(wrap(split));
        expect(tester.element(find.byKey(_w1)).size, const Size(395, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(395, 600));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(10, 600));
      });

      testWidgets('with 75% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.75);
        await tester.pumpWidget(wrap(split));
        expect(tester.element(find.byKey(_w1)).size, const Size(595, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(195, 600));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(10, 600));
      });

      testWidgets('with 0% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.0);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(0, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(790, 600));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(10, 600));
      });

      testWidgets('with 100% space to first child',
          (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 1.0);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(790, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(0, 600));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(10, 600));
      });
    });

    group('builds vertical layout', () {
      testWidgets('with 25% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.25);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 145));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 445));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(800, 10));
      });

      testWidgets('with 50% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.5);
        await tester.pumpWidget(wrap(split));
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 295));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 295));
      });

      testWidgets('with 75% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.75);
        await tester.pumpWidget(wrap(split));
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 445));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 145));
      });

      testWidgets('with 0% space to first child', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.0);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 0));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 590));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(800, 10));
      });

      testWidgets('with 100% space to first child',
          (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 1.0);
        await tester.pumpWidget(wrap(split));
        expect(find.byKey(_w1), findsOneWidget);
        expect(find.byKey(_w2), findsOneWidget);
        expect(find.byKey(split.dividerKey), findsOneWidget);
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 590));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 0));
        expect(tester.element(find.byKey(split.dividerKey)).size,
            const Size(800, 10));
      });
    });

    group('drags properly', () {
      testWidgets('with horizontal layout', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.5);
        await tester.pumpWidget(wrap(split));

        // We start at 0.5 size.
        expect(tester.element(find.byKey(_w1)).size, const Size(395, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(395, 600));

        // Drag to 0.75 first child size.
        await tester.drag(find.byKey(split.dividerKey), const Offset(200, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(595, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(195, 600));

        // Drag to 0.25 first child size.
        await tester.drag(find.byKey(split.dividerKey), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(195, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(595, 600));

        // Drag past the right end of the widget.
        await tester.drag(find.byKey(split.dividerKey), const Offset(600, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(790, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(0, 600));

        // Make sure we can't overdrag.
        await tester.drag(find.byKey(split.dividerKey), const Offset(200, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(790, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(0, 600));

        // Drag back past the left end of the widget.
        await tester.drag(find.byKey(split.dividerKey), const Offset(-800, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(0, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(790, 600));

        // Make sure we can't overdrag.
        await tester.drag(find.byKey(split.dividerKey), const Offset(-200, 0));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(0, 600));
        expect(tester.element(find.byKey(_w2)).size, const Size(790, 600));
      });

      testWidgets('with vertical layout', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.5);
        await tester.pumpWidget(wrap(split));

        // We start at 0.5 size.
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 295));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 295));

        // Drag to 0.75 first child size.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, 150));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 445));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 145));

        // Drag to 0.25 first child size.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 145));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 445));

        // Drag past the right end of the widget.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, 450));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 590));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 0));

        // Make sure we can't overdrag.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 590));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 0));

        // Drag back past the left end of the widget.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 0));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 590));

        // Make sure we can't overdrag.
        await tester.drag(find.byKey(split.dividerKey), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_w1)).size, const Size(800, 0));
        expect(tester.element(find.byKey(_w2)).size, const Size(800, 590));
      });
    });

    group('resizes contents', () {
      testWidgets('in a horizontal layout', (WidgetTester tester) async {
        final split = buildSplit(Axis.horizontal, initialFirstFraction: 0.0);
        await tester.pumpWidget(wrap(
          Center(
            child: SizedBox(width: 300.0, height: 300.0, child: split),
          ),
        ));
        expect(tester.element(find.byKey(_w1)).size, const Size(0, 300));
        expect(tester.element(find.byKey(_w2)).size, const Size(290, 300));

        await tester.pumpWidget(wrap(
          Center(
            child: SizedBox(width: 200.0, height: 200.0, child: split),
          ),
        ));
        expect(tester.element(find.byKey(_w1)).size, const Size(0, 200));
        expect(tester.element(find.byKey(_w2)).size, const Size(190, 200));
      });

      testWidgets('in a vertical layout', (WidgetTester tester) async {
        final split = buildSplit(Axis.vertical, initialFirstFraction: 0.0);
        await tester.pumpWidget(wrap(
          Center(
            child: SizedBox(width: 300.0, height: 300.0, child: split),
          ),
        ));
        expect(tester.element(find.byKey(_w1)).size, const Size(300, 0));
        expect(tester.element(find.byKey(_w2)).size, const Size(300, 290));

        await tester.pumpWidget(wrap(
          Center(
            child: SizedBox(width: 200.0, height: 200.0, child: split),
          ),
        ));
        expect(tester.element(find.byKey(_w1)).size, const Size(200, 0));
        expect(tester.element(find.byKey(_w2)).size, const Size(200, 190));
      });
    });

    group('axisFor', () {
      testWidgets('return Axis.horizontal', (WidgetTester tester) async {
        await setWindowSize(const Size(800, 800));
        await tester.pumpWidget(wrap(Builder(
          builder: (context) {
            expectLater(Split.axisFor(context, 1.0), Axis.horizontal);
            return Container();
          },
        )));
      });
      testWidgets('return Axis.vertical', (WidgetTester tester) async {
        await setWindowSize(const Size(500, 800));
        await tester.pumpWidget(wrap(Builder(
          builder: (context) {
            expectLater(Split.axisFor(context, 1.0), Axis.vertical);
            return Container();
          },
        )));
      });
    });
  });
}

const _w1 = Key('child 1');
const _w2 = Key('child 2');
Split buildSplit(Axis axis, {@required double initialFirstFraction}) {
  const w1 = Text('content1', key: _w1);
  const w2 = Text('content2', key: _w2);
  return Split(
    axis: axis,
    firstChild: w1,
    secondChild: w2,
    initialFirstFraction: initialFirstFraction,
  );
}
