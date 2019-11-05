// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/flutter/story_of_your_layout/arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget widget) => MaterialApp(home: widget);

  group('Arrow Golden Tests', () {
    group('Unidirectional', () {
      Widget buildUnidirectionalArrowWrapper(ArrowType type) => wrap(
            Container(
              width: 100,
              height: 100,
              child: ArrowWrapper.unidirectional(
                child: const Text('1'),
                type: type,
                arrowStrokeWidth: 2.0,
                arrowColor: Colors.black,
                arrowHeadSize: 8.0,
              ),
            ),
          );
      testWidgets('left', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.left);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_left.png'),
        );
      });
      testWidgets('up', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.up);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_up.png'),
        );
      });
      testWidgets('right', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.right);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_right.png'),
        );
      });
      testWidgets('down', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.down);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_down.png'),
        );
      });
    });
    group('Bidirectional', () {
      Widget buildBidirectionalArrowWrapper(Axis direction) => wrap(
            Container(
              width: 100,
              height: 100,
              child: ArrowWrapper.bidirectional(
                child: const Text('1'),
                direction: direction,
                arrowStrokeWidth: 2.0,
                arrowColor: Colors.black,
                arrowHeadSize: 8.0,
              ),
            ),
          );
      testWidgets('horizontal', (WidgetTester tester) async {
        final widget = buildBidirectionalArrowWrapper(Axis.horizontal);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_bidirectional_horizontal.png'),
        );
      });
      testWidgets('vertical', (WidgetTester tester) async {
        final widget = buildBidirectionalArrowWrapper(Axis.vertical);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_bidirectional_vertical.png'),
        );
      });
    });
  });
}
