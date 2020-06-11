// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools_app/src/flex_split_column.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlexSplitColumn', () {
    // The UI of the FlexSplitColumn widget is well tested in [split_test.dart].
    // These tests test the data transformations that take place upon
    // constructing [FlexSplitColumn].

    const children = [SizedBox(), SizedBox(), SizedBox(), SizedBox()];
    const firstHeaderKey = Key('first header');
    const headers = [
      SizedBox(height: 50.0, key: firstHeaderKey),
      SizedBox(height: 50.0),
      SizedBox(height: 50.0),
      SizedBox(height: 50.0),
    ];
    const initialFractions = [0.25, 0.25, 0.25, 0.25];
    const minSizes = [10.0, 10.0, 10.0, 10.0];
    const totalHeight = 1200.0;

    test('modifyInitialFractionsToIncludeFirstHeader', () {
      final adjustedFractions =
          FlexSplitColumn.modifyInitialFractionsToIncludeFirstHeader(
        initialFractions,
        headers,
        totalHeight,
      );
      expect(
        collectionEquals(
          adjustedFractions,
          [
            0.2857142857142857,
            0.23809523809523808,
            0.23809523809523808,
            0.23809523809523808
          ],
        ),
        isTrue,
      );
    });

    test('modifyMinSizesToIncludeFirstHeader', () {
      final adjustedFractions =
          FlexSplitColumn.modifyMinSizesToIncludeFirstHeader(
        minSizes,
        headers,
      );
      expect(collectionEquals(adjustedFractions, [60.0, 10.0, 10.0, 10.0]),
          isTrue);
    });

    testWidgets('buildChildrenWithFirstHeader', (WidgetTester tester) async {
      await tester.pumpWidget(Column(children: children));
      expect(find.byKey(firstHeaderKey), findsNothing);

      // Wrap each child in a container so we can build the elements in a
      // arbitrary column to check for [firstHeaderKey].
      final adjustedChildren =
          FlexSplitColumn.buildChildrenWithFirstHeader(children, headers)
              .map((child) => Container(height: 100.0, child: child))
              .toList();
      await tester.pumpWidget(Column(children: adjustedChildren));
      expect(find.byKey(firstHeaderKey), findsOneWidget);
    });
  });
}
