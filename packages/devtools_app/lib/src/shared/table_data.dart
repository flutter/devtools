// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../primitives/trees.dart';
import 'utils.dart';

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

  bool get disableHeader => false;

  bool get supportsSorting => numeric;

  int compare(T a, T b) {
    final valueA = getValue(a) as Comparable;
    final valueB = getValue(b) as Comparable;
    return valueA.compareTo(valueB);
  }

  /// Get the cell's value from the given [dataObject].
  Object? getValue(T dataObject);

  /// Get the cell's display value from the given [dataObject].
  String getDisplayValue(T dataObject) =>
      getValue(dataObject)?.toString() ?? '';

  // TODO(kenz): this isn't hooked up to the table elements. Do this.
  /// Get the cell's tooltip value from the given [dataObject].
  String getTooltip(T dataObject) => getDisplayValue(dataObject);

  /// Get the cell's text color from the given [dataObject].
  Color? getTextColor(T dataObject) => null;

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
