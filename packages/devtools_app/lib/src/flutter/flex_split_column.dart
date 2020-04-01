// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import 'split.dart';

class FlexSplitColumn extends StatelessWidget {
  FlexSplitColumn({
    Key key,
    @required this.totalHeight,
    @required this.headers,
    @required List<Widget> children,
    @required List<double> initialFractions,
    List<double> minSizes,
  })  : assert(children != null && children.length >= 2),
        assert(initialFractions != null && initialFractions.length >= 2),
        assert(children.length == initialFractions.length),
        adjustedChildren = adjustChildren(children, headers),
        adjustedInitialFractions =
            adjustInitialFractions(initialFractions, headers, totalHeight),
        adjustedMinSizes = adjustMinSizes(minSizes, headers),
        super(key: key) {
    if (minSizes != null) {
      assert(minSizes.length == children.length);
    }
  }

  /// The headers that will be laid out above each corresponding child in
  /// [children].
  ///
  /// All headers but the first will be passed into [Split.splitters] when
  /// creating the [Split] widget in `build`. Instead of being passed into
  /// [Split.splitters], it will be combined with the first child in [children]
  /// to create the first child we will pass into [Split.children].
  ///
  /// We do this because the first header will not actually be a splitter as
  /// there is not any content above it for it to split.
  ///
  /// We adjust other values [adjustedChildren], [adjustedInitialFractions], and
  /// [adjustedMinSizes] to account for the first header. We do this adjustment
  /// here so that the creators of [FlexSplitColumn] can be unaware of
  /// the under-the-hood calculations necessary to achieve the UI requirements
  /// specified by [initialFractions] and [minSizes].
  final List<FlexSplitColumnHeader> headers;

  /// The children that will be laid out below each corresponding header in
  /// [headers].
  ///
  /// All [children] except the first will be passed into [Split.children]
  /// unmodified. We need to adjust the first child from [children] to account
  /// for the first header (see above).
  final List<Widget> adjustedChildren;

  /// The fraction of the layout to allocate to each child in [children].
  ///
  /// We need to adjust the values given by [initialFractions] to account for
  /// the first header (see above).
  final List<double> adjustedInitialFractions;

  /// The minimum size each child is allowed to be.
  final List<double> adjustedMinSizes;

  /// The total height of the column, including all [headers] and [children].
  final double totalHeight;

  @visibleForTesting
  static List<Widget> adjustChildren(
    List<Widget> children,
    List<FlexSplitColumnHeader> headers,
  ) {
    return [
      Column(
        children: [
          headers[0],
          Expanded(child: children[0]),
        ],
      ),
      ...children.sublist(1),
    ];
  }

  @visibleForTesting
  static List<double> adjustInitialFractions(
    List<double> initialFractions,
    List<FlexSplitColumnHeader> headers,
    double totalHeight,
  ) {
    final intendedContentHeight = totalHeight -
        headers.map((header) => header.height).reduce((a, b) => a + b);
    final intendedChildHeights = List<double>.generate(initialFractions.length,
        (i) => intendedContentHeight * initialFractions[i]);
    final trueContentHeight = intendedContentHeight + headers[0].height;
    return List<double>.generate(initialFractions.length, (i) {
      if (i == 0) {
        return (intendedChildHeights[i] + headers[0].height) /
            trueContentHeight;
      }
      return intendedChildHeights[i] / trueContentHeight;
    });
  }

  @visibleForTesting
  static List<double> adjustMinSizes(
    List<double> minSizes,
    List<FlexSplitColumnHeader> headers,
  ) {
    return [
      minSizes[0] + headers[0].height,
      ...minSizes.sublist(1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.vertical,
      children: adjustedChildren,
      initialFractions: adjustedInitialFractions,
      minSizes: adjustedMinSizes,
      splitters: headers.sublist(1),
    );
  }
}

class FlexSplitColumnHeader extends SizedBox {
  const FlexSplitColumnHeader({
    @required double width,
    @required double height,
    @required Widget child,
  }) : super(width: width, height: height, child: child);
}
