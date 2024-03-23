// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../primitives/byte_utils.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';

/// Defines how a column should display data in a table.
///
/// [ColumnData] objects should be defined as static where possible, and should
/// not manage any stateful data. The table controllers expect columns to be
/// solely responsible for declaring how to layout table data.
///
/// Any data that can't be stored on the [dataObject] may be accessed by passing
/// a long-living controller to the constructor of the [ColumnData] subclass.
///
/// The controller is expected to be alive for the duration of the app
/// connection.
abstract class ColumnData<T> {
  ColumnData(
    this.title, {
    required double this.fixedWidthPx,
    this.titleTooltip,
    this.alignment = ColumnAlignment.left,
    this.headerAlignment = TextAlign.left,
  }) : minWidthPx = null;

  ColumnData.wide(
    this.title, {
    this.titleTooltip,
    this.minWidthPx,
    this.alignment = ColumnAlignment.left,
    this.headerAlignment = TextAlign.left,
  }) : fixedWidthPx = null;

  final String title;

  final String? titleTooltip;

  /// Width of the column expressed as a fixed number of pixels.
  final double? fixedWidthPx;

  /// The minimum width that should be used for a variable width column.
  final double? minWidthPx;

  /// How much to indent the data object by.
  ///
  /// This should only be non-zero for [TreeColumnData].
  double getNodeIndentPx(T dataObject) => 0.0;

  final ColumnAlignment alignment;

  final TextAlign headerAlignment;

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

  /// Get the cell's tooltip value from the given [dataObject].
  String getTooltip(T dataObject) => getDisplayValue(dataObject);

  /// Get the cell's rich tooltip span from the given [dataObject].
  ///
  /// If both [getTooltip] and [getRichTooltip] are provided, the rich tooltip
  /// will take precedence.
  InlineSpan? getRichTooltip(T dataObject, BuildContext context) => null;

  /// Get the cell's text color from the given [dataObject].
  Color? getTextColor(T dataObject) => null;

  TextStyle? contentTextStyle(
    BuildContext context,
    T dataObject, {
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final textColor = getTextColor(dataObject) ?? theme.colorScheme.onSurface;
    return theme.regularTextStyleWithColor(textColor);
  }

  /// The configuration for the column. Configuration changes to columns
  /// will cause the table to be rebuilt.
  /// 
  /// Defaults to title.
  String get config => title;

  @override
  String toString() => title;
}

abstract class TreeColumnData<T extends TreeNode<T>> extends ColumnData<T> {
  TreeColumnData(String title) : super.wide(title);

  static double get treeToggleWidth => scaleByFontFactor(14.0);

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
  ColumnGroup({required this.title, required this.range});

  ColumnGroup.fromText({
    required String title,
    required Range range,
    String? tooltip,
  }) : this(
          title: maybeWrapWithTooltip(child: Text(title), tooltip: tooltip),
          range: range,
        );

  final Widget title;

  /// The range of column indices for columns that make up this group.
  final Range range;
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

  TextAlign get contentTextAlignment {
    switch (alignment) {
      case ColumnAlignment.center:
        return TextAlign.center;
      case ColumnAlignment.right:
        return TextAlign.right;
      case ColumnAlignment.left:
      default:
        return TextAlign.left;
    }
  }
}

typedef RichTooltipBuilder<T> = InlineSpan? Function(T, BuildContext);

/// Column that, for each row, shows a time value in milliseconds and the
/// percentage that the time value is of the total time for this data set.
///
/// Both time and percentage are provided through callbacks [timeProvider] and
/// [percentAsDoubleProvider], respectively.
///
/// When [percentageOnly] is true, the time value will be omitted, and only the
/// percentage will be displayed.
abstract class TimeAndPercentageColumn<T> extends ColumnData<T> {
  TimeAndPercentageColumn({
    required String title,
    required this.percentAsDoubleProvider,
    this.timeProvider,
    this.tooltipProvider,
    this.richTooltipProvider,
    this.secondaryCompare,
    this.percentageOnly = false,
    double columnWidth = _defaultTimeColumnWidth,
    super.titleTooltip,
  }) : super(
          title,
          fixedWidthPx: scaleByFontFactor(columnWidth),
        );

  static const _defaultTimeColumnWidth = 120.0;

  Duration Function(T)? timeProvider;

  double Function(T) percentAsDoubleProvider;

  String Function(T)? tooltipProvider;

  RichTooltipBuilder<T>? richTooltipProvider;

  Comparable Function(T)? secondaryCompare;

  final bool percentageOnly;

  @override
  bool get numeric => true;

  @override
  int compare(T a, T b) {
    final int result = super.compare(a, b);
    if (result == 0 && secondaryCompare != null) {
      return secondaryCompare!(a).compareTo(secondaryCompare!(b));
    }
    return result;
  }

  @override
  double getValue(T dataObject) => percentageOnly
      ? percentAsDoubleProvider(dataObject)
      : timeProvider!(dataObject).inMicroseconds.toDouble();

  @override
  String getDisplayValue(T dataObject) {
    if (percentageOnly) return _percentDisplay(dataObject);
    return _timeAndPercentage(dataObject);
  }

  @override
  String getTooltip(T dataObject) {
    if (tooltipProvider != null) {
      return tooltipProvider!(dataObject);
    }
    if (percentageOnly && timeProvider != null) {
      return _timeAndPercentage(dataObject);
    }
    return '';
  }

  @override
  InlineSpan? getRichTooltip(T dataObject, BuildContext context) =>
      richTooltipProvider?.call(dataObject, context);

  String _timeAndPercentage(T dataObject) =>
      '${durationText(timeProvider!(dataObject), fractionDigits: 2)} (${_percentDisplay(dataObject)})';

  String _percentDisplay(T dataObject) =>
      percent(percentAsDoubleProvider(dataObject));
}

/// Column that, for each row, shows a memory value and the percentage that the
/// memory value is of the total memory for this data set.
///
/// Both memory and percentage are provided through callbacks [sizeProvider] and
/// [percentAsDoubleProvider], respectively.
///
/// When [percentageOnly] is true, the memory value will be omitted, and only the
/// percentage will be displayed.
abstract class SizeAndPercentageColumn<T> extends ColumnData<T> {
  SizeAndPercentageColumn({
    required String title,
    required this.percentAsDoubleProvider,
    this.sizeProvider,
    this.tooltipProvider,
    this.richTooltipProvider,
    this.secondaryCompare,
    this.percentageOnly = false,
    double columnWidth = _defaultMemoryColumnWidth,
    super.titleTooltip,
  }) : super(
          title,
          fixedWidthPx: scaleByFontFactor(columnWidth),
        );

  static const _defaultMemoryColumnWidth =
      TimeAndPercentageColumn._defaultTimeColumnWidth;

  int Function(T)? sizeProvider;

  double Function(T) percentAsDoubleProvider;

  String Function(T)? tooltipProvider;

  RichTooltipBuilder<T>? richTooltipProvider;

  Comparable Function(T)? secondaryCompare;

  final bool percentageOnly;

  @override
  bool get numeric => true;

  @override
  int compare(T a, T b) {
    final int result = super.compare(a, b);
    if (result == 0 && secondaryCompare != null) {
      return secondaryCompare!(a).compareTo(secondaryCompare!(b));
    }
    return result;
  }

  @override
  double getValue(T dataObject) => percentageOnly
      ? percentAsDoubleProvider(dataObject)
      : sizeProvider!(dataObject).toDouble();

  @override
  String getDisplayValue(T dataObject) {
    if (percentageOnly) return _percentDisplay(dataObject);
    return _memoryAndPercentage(dataObject);
  }

  @override
  String getTooltip(T dataObject) {
    if (tooltipProvider != null) {
      return tooltipProvider!(dataObject);
    }
    if (percentageOnly && sizeProvider != null) {
      return _memoryAndPercentage(dataObject);
    }
    return '';
  }

  @override
  InlineSpan? getRichTooltip(T dataObject, BuildContext context) =>
      richTooltipProvider?.call(dataObject, context);

  String _memoryAndPercentage(T dataObject) =>
      '${prettyPrintBytes(sizeProvider!(dataObject), includeUnit: true, kbFractionDigits: 0)}'
      ' (${_percentDisplay(dataObject)})';

  String _percentDisplay(T dataObject) =>
      percent(percentAsDoubleProvider(dataObject));
}
