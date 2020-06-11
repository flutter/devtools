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
        _children = buildChildrenWithFirstHeader(children, headers),
        _initialFractions = modifyInitialFractionsToIncludeFirstHeader(
            initialFractions, headers, totalHeight),
        _minSizes = modifyMinSizesToIncludeFirstHeader(minSizes, headers),
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
  /// We modify other values [_children], [_initialFractions], and [_minSizes]
  /// from [children], [initialFractions], and [minSizes], respectively, to
  /// account for the first header. We do this adjustment here so that the
  /// creators of [FlexSplitColumn] can be unaware of the under-the-hood
  /// calculations necessary to achieve the UI requirements specified by
  /// [initialFractions] and [minSizes].
  final List<SizedBox> headers;

  /// The children that will be laid out below each corresponding header in
  /// [headers].
  ///
  /// All [children] except the first will be passed into [Split.children]
  /// unmodified. We need to modify the first child from [children] to account
  /// for the first header (see above).
  final List<Widget> _children;

  /// The fraction of the layout to allocate to each child in [children].
  ///
  /// We need to modify the values given by [initialFractions] to account for
  /// the first header (see above).
  final List<double> _initialFractions;

  /// The minimum size each child is allowed to be.
  ///
  /// We need to modify the values given by [minSizes] to account for the first
  /// header (see above).
  final List<double> _minSizes;

  /// The total height of the column, including all [headers] and [children].
  final double totalHeight;

  @visibleForTesting
  static List<Widget> buildChildrenWithFirstHeader(
    List<Widget> children,
    List<SizedBox> headers,
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
  static List<double> modifyInitialFractionsToIncludeFirstHeader(
    List<double> initialFractions,
    List<SizedBox> headers,
    double totalHeight,
  ) {
    var totalHeaderHeight = 0.0;
    for (var header in headers) {
      totalHeaderHeight += header.height;
    }
    final intendedContentHeight = totalHeight - totalHeaderHeight;
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
  static List<double> modifyMinSizesToIncludeFirstHeader(
    List<double> minSizes,
    List<SizedBox> headers,
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
      children: _children,
      initialFractions: _initialFractions,
      minSizes: _minSizes,
      splitters: headers.sublist(1),
    );
  }
}
