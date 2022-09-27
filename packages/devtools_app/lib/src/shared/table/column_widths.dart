// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../theme.dart';
import 'table_controller.dart';
import 'table_data.dart';

// TODO(https://github.com/flutter/devtools/issues/2047): build flexible column
// widths into the tables so that we do not have to do in depth calculations
// like this.

const columnGroupSpacing = 4.0;
const columnGroupSpacingWithPadding = columnGroupSpacing + 2 * defaultSpacing;
const columnSpacing = defaultSpacing;

extension FlatColumnWidthExtension<T> on FlatTableController<T> {
  List<double> computeColumnWidths(double maxWidth) {
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
  /// The width to assume for columns that don't specify a width.
  static const _defaultColumnWidth = 500.0;

  List<double> computeColumnWidths(List<T> flattenedList) {
    final firstRoot = dataRoots.first;
    var deepest = firstRoot;
    // This will use the width of all rows in the table, even the rows
    // that are hidden by nesting.
    // We may want to change this to using a flattened list of only
    // the list items that should show right now.
    for (var node in flattenedList) {
      if (node.level > deepest.level) {
        deepest = node;
      }
    }
    final widths = <double>[];
    for (var column in columns) {
      var width = column.getNodeIndentPx(deepest);
      assert(width >= 0.0);
      if (column.fixedWidthPx != null) {
        width += column.fixedWidthPx!;
      } else {
        // TODO(djshuckerow): measure the text of the longest content
        // to get an idea for how wide this column should be.
        // Text measurement is a somewhat expensive algorithm, so we don't
        // want to do it for every row in the table, only the row
        // we are confident is the widest.  A reasonable heuristic is the row
        // with the longest text, but because of variable-width fonts, this is
        // not always true.
        width += _defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }
}
