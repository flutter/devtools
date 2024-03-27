// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'split_pane.dart';

/// A widget that takes a list of [children] and lays them out in a column where
/// each child has a flexible height.
///
/// Each child in [children] must have an accompanying header in [header]. Since
/// each header must be a [PreferredSizeWidget], it is common to use the shared
/// widgets [AreaPaneHeader] or [BlankHeader] for the column [headers].
///
/// The user can customize the amount of space allocated to each child by
/// clicking and dragging the [header]s that separate the children.
///
/// [initialFractions] defines how much space to give each child when building
/// this widget.
///
/// [minSizes] defines the minimum size that each child can be set to when
/// adjusting the sizes of the children.
final class FlexSplitColumn extends StatelessWidget {
  FlexSplitColumn({
    Key? key,
    required this.totalHeight,
    required this.headers,
    required List<Widget> children,
    required List<double> initialFractions,
    required List<double> minSizes,
  })  : assert(children.length >= 2),
        assert(initialFractions.length >= 2),
        assert(children.length == initialFractions.length),
        assert(minSizes.length == children.length),
        _children = buildChildrenWithFirstHeader(children, headers),
        _initialFractions = modifyInitialFractionsToIncludeFirstHeader(
          initialFractions,
          headers,
          totalHeight,
        ),
        _minSizes = modifyMinSizesToIncludeFirstHeader(minSizes, headers),
        super(key: key);

  /// The headers that will be laid out above each corresponding child in
  /// [children].
  ///
  /// All headers but the first will be passed into [SplitPane.splitters] when
  /// creating the [SplitPane] widget in `build`. Instead of being passed into
  /// [SplitPane.splitters], it will be combined with the first child in [children]
  /// to create the first child we will pass into [SplitPane.children].
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
  final List<PreferredSizeWidget> headers;

  /// The children that will be laid out below each corresponding header in
  /// [headers].
  ///
  /// All [children] except the first will be passed into [SplitPane.children]
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
    List<PreferredSizeWidget> headers,
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
    List<PreferredSizeWidget> headers,
    double totalHeight,
  ) {
    var totalHeaderHeight = 0.0;
    for (var header in headers) {
      totalHeaderHeight += header.preferredSize.height;
    }
    final intendedContentHeight = totalHeight - totalHeaderHeight;
    final intendedChildHeights = List<double>.generate(
      initialFractions.length,
      (i) => intendedContentHeight * initialFractions[i],
    );
    final trueContentHeight =
        intendedContentHeight + headers[0].preferredSize.height;
    return List<double>.generate(initialFractions.length, (i) {
      if (i == 0) {
        return (intendedChildHeights[i] + headers[0].preferredSize.height) /
            trueContentHeight;
      }
      return intendedChildHeights[i] / trueContentHeight;
    });
  }

  @visibleForTesting
  static List<double> modifyMinSizesToIncludeFirstHeader(
    List<double> minSizes,
    List<PreferredSizeWidget> headers,
  ) {
    return [
      minSizes[0] + headers[0].preferredSize.height,
      ...minSizes.sublist(1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SplitPane(
      axis: Axis.vertical,
      initialFractions: _initialFractions,
      minSizes: _minSizes,
      splitters: headers.sublist(1),
      children: _children,
    );
  }
}
