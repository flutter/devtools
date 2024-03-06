// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/src/ui/flex_split_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlexSplitColumn', () {
    // The UI of the FlexSplitColumn widget is well tested in [SplitPane_test.dart].
    // These tests test the data transformations that take place upon
    // constructing [FlexSplitColumn].

    const children = [SizedBox(), SizedBox(), SizedBox(), SizedBox()];
    const firstHeaderKey = Key('first header');
    const headers = [
      PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: SizedBox(height: 50.0, key: firstHeaderKey),
      ),
      PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: SizedBox(height: 50.0),
      ),
      PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: SizedBox(height: 50.0),
      ),
      PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: SizedBox(height: 50.0),
      ),
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
        const DeepCollectionEquality().equals(
          adjustedFractions,
          [
            0.2857142857142857,
            0.23809523809523808,
            0.23809523809523808,
            0.23809523809523808,
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
      expect(
        const DeepCollectionEquality()
            .equals(adjustedFractions, [60.0, 10.0, 10.0, 10.0]),
        isTrue,
      );
    });

    testWidgets('buildChildrenWithFirstHeader', (WidgetTester tester) async {
      await tester.pumpWidget(const Column(children: children));
      expect(find.byKey(firstHeaderKey), findsNothing);

      // Wrap each child in a container so we can build the elements in a
      // arbitrary column to check for [firstHeaderKey].
      final adjustedChildren =
          FlexSplitColumn.buildChildrenWithFirstHeader(children, headers)
              .map((child) => SizedBox(height: 100.0, child: child))
              .toList();
      await tester.pumpWidget(Column(children: adjustedChildren));
      expect(find.byKey(firstHeaderKey), findsOneWidget);
    });
  });
}
