// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../utils.dart';

// TODO(peterdjlee): Remove get from method names.
abstract class ColumnData<T> {
  ColumnData(
    this.title, {
    this.titleTooltip,
    required double this.fixedWidthPx,
    this.alignment = ColumnAlignment.left,
  }) : minWidthPx = null;

  ColumnData.wide(
    this.title, {
    this.titleTooltip,
    this.minWidthPx,
    this.alignment = ColumnAlignment.left,
  }) : fixedWidthPx = null;

  final String title;

  final String? titleTooltip;

  /// Width of the column expressed as a fixed number of pixels.
  final double? fixedWidthPx;

  final double? minWidthPx;

  /// How much to indent the data object by.
  ///
  /// This should only be non-zero for [TreeColumnData].
  double getNodeIndentPx(T dataObject) => 0.0;

  final ColumnAlignment alignment;

  bool get numeric => false;

  bool get includeHeader => true;

  bool get supportsSorting => numeric;

  int compare(T a, T b) {
    final valueA = getValue(a);
    final valueB = getValue(b);
    if (valueA == null && valueB == null) return 0;
    if (valueA == null) return -1;
    if (valueB == null) return 1;
    return (valueA as Comparable).compareTo(valueB as Comparable);
  }

  /// Get the cell's value from the given [dataObject].
  Object? getValue(T dataObject);

  /// Get the cell's display value from the given [dataObject].
  String getDisplayValue(T dataObject) =>
      getValue(dataObject)?.toString() ?? '';

  String? getCaption(T dataObject) => null;

  // TODO(kenz): this isn't hooked up to the table elements. Do this.
  /// Get the cell's tooltip value from the given [dataObject].
  String getTooltip(T dataObject) => getDisplayValue(dataObject);

  /// Get the cell's text color from the given [dataObject].
  Color? getTextColor(T dataObject) => null;

  TextStyle? contentTextStyle(
    BuildContext context,
    T dataObject, {
    bool isSelected = false,
  }) {
    final textColor =
        isSelected ? defaultSelectionForegroundColor : getTextColor(dataObject);
    final fontStyle = Theme.of(context).fixedFontStyle;
    return textColor == null ? fontStyle : fontStyle.copyWith(color: textColor);
  }

  @override
  String toString() => title;
}

abstract class TreeColumnData<T extends TreeNode<T>> extends ColumnData<T> {
  TreeColumnData(String title) : super.wide(title);

  static double get treeToggleWidth => scaleByFontFactor(14.0);

  final StreamController<T> nodeExpandedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeExpanded => nodeExpandedController.stream;

  final StreamController<T> nodeCollapsedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeCollapsed => nodeCollapsedController.stream;

  @override
  double getNodeIndentPx(T dataObject) {
    return dataObject.level * treeToggleWidth;
  }
}

enum ColumnAlignment {
  left,
  right,
  center,
}

mixin PinnableListEntry {
  /// Determines if the row should be pinned to the top of the table.
  bool get pinToTop => false;
}

/// Defines a group of columns for use in a table.
///
/// Use a column group when multiple columns should be grouped together in the
/// table with a common title. In a table with column groups, visual dividers
/// will be drawn between groups and an additional header row will be added to
/// the table to display the column group titles.
class ColumnGroup {
  ColumnGroup({required this.title, required this.range, this.tooltip});

  final String title;

  /// The range of column indices for columns that make up this group.
  final Range range;

  final String? tooltip;
}

extension ColumnDataExtension<T> on ColumnData<T> {
  MainAxisAlignment get mainAxisAlignment {
    switch (alignment) {
      case ColumnAlignment.center:
        return MainAxisAlignment.center;
      case ColumnAlignment.right:
        return MainAxisAlignment.end;
      case ColumnAlignment.left:
      default:
        return MainAxisAlignment.start;
    }
  }
}
