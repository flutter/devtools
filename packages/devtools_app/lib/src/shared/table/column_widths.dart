// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';

import '../primitives/trees.dart';
import '../primitives/utils.dart';
import 'table_controller.dart';
import 'table_data.dart';

// TODO(https://github.com/flutter/devtools/issues/2047): build flexible column
// widths into the tables so that we do not have to do in depth calculations
// like this.

const columnGroupSpacing = 4.0;
const columnGroupSpacingWithPadding = columnGroupSpacing + 2 * defaultSpacing;
const columnSpacing = defaultSpacing;

/// The minimum width that can be used for variable width columns.
final defaultVariableWidthColumnSize = scaleByFontFactor(1200.0);

extension FlatColumnWidthExtension<T> on FlatTableController<T> {
  /// Calculates [FlatTable] column widths when the columns should be sized as
  /// either 1) the [fixedWidthPx] specified by the column, or
  /// 2) [defaultVariableWidthColumnSize], the minimum width that can be used
  /// for variable width columns.
  ///
  /// If the sum of the column widths exceeds the available screen space, the
  /// table will scroll horizontally.
  List<double> computeColumnWidthsSizeToContent() {
    return columns
        .map(
          (c) =>
              c.fixedWidthPx ??
              (c.minWidthPx ?? defaultVariableWidthColumnSize),
        )
        .toList();
  }

  /// Calculates [FlatTable] column widths such that they will take up the
  /// entire width available [maxWidth].
  ///
  /// When this calculation method is used, the table will not scroll
  /// horizontally since there will not be any content outside of the viewport.
  List<double> computeColumnWidthsSizeToFit(double maxWidth) {
    // Subtract width from outer padding around table.
    maxWidth -= 2 * defaultSpacing;
    final numColumnGroupSpacers = columnGroups?.numSpacers ?? 0;
    final numColumnSpacers = columns.numSpacers - numColumnGroupSpacers;
    maxWidth -= numColumnSpacers * columnSpacing;
    maxWidth -= numColumnGroupSpacers * columnGroupSpacingWithPadding;
    maxWidth = max(0, maxWidth);
    double available = maxWidth;
    // Columns sorted by increasing minWidth.
    final List<ColumnData<T>> sortedColumns = columns.toList()
      ..sort((a, b) {
        if (a.minWidthPx != null && b.minWidthPx != null) {
          return a.minWidthPx!.compareTo(b.minWidthPx!);
        }
        if (a.minWidthPx != null) return -1;
        if (b.minWidthPx != null) return 1;
        return 0;
      });

    for (var col in columns) {
      if (col.fixedWidthPx != null) {
        available -= col.fixedWidthPx!;
      } else if (col.minWidthPx != null) {
        available -= col.minWidthPx!;
      }
    }
    available = max(available, 0);
    int unconstrainedCount = 0;
    for (var column in sortedColumns) {
      if (column.fixedWidthPx == null && column.minWidthPx == null) {
        unconstrainedCount++;
      }
    }

    if (available > 0) {
      // We need to find how many columns with minWidth constraints can actually
      // be treated as unconstrained as their minWidth constraint is satisfied
      // by the width given to all unconstrained columns.
      // We use a greedy algorithm to accurately compute this by iterating
      // through the columns from the smallest minWidth to largest minWidth
      // incrementally adding columns where the minWidth constraint can be
      // satisfied using the width given to unconstrained columns.
      for (var column in sortedColumns) {
        if (column.fixedWidthPx == null && column.minWidthPx != null) {
          // Width of this column if it was not clamped to its min width.
          // We add column.minWidthPx to the available width because
          // available is currently not considering the space reserved for this
          // column's min width as available.
          final widthIfUnconstrainedByMinWidth =
              (available + column.minWidthPx!) / (unconstrainedCount + 1);
          if (widthIfUnconstrainedByMinWidth < column.minWidthPx!) {
            // We have found the first column that will have to be clamped to
            // its min width.
            break;
          }
          // As this column's width in the final layout is greater than its
          // min width, we can treat it as unconstrained and give its min width
          // back to the available pool.
          unconstrainedCount++;
          available += column.minWidthPx!;
        }
      }
    }
    final unconstrainedWidth =
        unconstrainedCount > 0 ? available / unconstrainedCount : available;
    int unconstrainedFound = 0;
    final widths = <double>[];
    for (ColumnData<T> column in columns) {
      double? width = column.fixedWidthPx;
      if (width == null) {
        if (column.minWidthPx != null &&
            column.minWidthPx! > unconstrainedWidth) {
          width = column.minWidthPx!;
        } else {
          width = unconstrainedWidth;
          unconstrainedFound++;
        }
      }
      widths.add(width);
    }
    assert(unconstrainedCount == unconstrainedFound);
    return widths;
  }
}

extension TreeColumnWidthExtension<T extends TreeNode<T>>
    on TreeTableController<T> {
  /// Calculates [TreeTable] column widths.
  ///
  /// Non-tree columns will be sized with their specified [fixedWidthPx]. The
  /// tree column width will include space for the max indentation of the fully
  /// expanded tree and [defaultVariableWidthColumnSize] for displaying the
  /// tree column content.
  ///
  /// If the sum of the column widths exceeds the available screen space, the
  /// table will scroll horizontally.
  List<double> computeColumnWidths(int maxTableDepth) {
    return columns
        .map(
          (c) =>
              c.fixedWidthPx ??
              maxTableDepth * TreeColumnData.treeToggleWidth +
                  defaultVariableWidthColumnSize,
        )
        .toList();
  }
}
