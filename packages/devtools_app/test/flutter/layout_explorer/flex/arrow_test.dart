// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/flutter/layout_explorer/flex/arrow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arrow Golden Tests', () {
    group('Unidirectional', () {
      Widget buildUnidirectionalArrowWrapper(ArrowType type) => Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              width: 100,
              height: 100,
              child: ArrowWrapper.unidirectional(
                child: Container(
                  width: 10,
                  height: 10,
                  color: Colors.red,
                ),
                type: type,
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
      }, skip: kIsWeb);
      testWidgets('up', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.up);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_up.png'),
        );
      }, skip: kIsWeb);
      testWidgets('right', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.right);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_right.png'),
        );
      }, skip: kIsWeb);
      testWidgets('down', (WidgetTester tester) async {
        final widget = buildUnidirectionalArrowWrapper(ArrowType.down);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_unidirectional_down.png'),
        );
      }, skip: kIsWeb);
    });

    group('Bidirectional', () {
      Widget buildBidirectionalArrowWrapper(Axis direction) => Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              width: 100,
              height: 100,
              child: ArrowWrapper.bidirectional(
                child: Container(
                  width: 10,
                  height: 10,
                  color: Colors.red,
                ),
                direction: direction,
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
      }, skip: kIsWeb);
      testWidgets('vertical', (WidgetTester tester) async {
        final widget = buildBidirectionalArrowWrapper(Axis.vertical);
        await tester.pumpWidget(widget);
        await expectLater(
          find.byWidget(widget),
          matchesGoldenFile('goldens/arrow_bidirectional_vertical.png'),
        );
      }, skip: kIsWeb);
    });
  });
}
