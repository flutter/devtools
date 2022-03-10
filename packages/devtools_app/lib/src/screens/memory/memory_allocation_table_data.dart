// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/utils.dart';
import 'memory_controller.dart';

const defaultNumberFieldWidth = 100.0;

class FieldTrack extends ColumnData<ClassHeapDetailStats>
    implements ColumnRenderer<ClassHeapDetailStats> {
  FieldTrack()
      : super(
          'Track',
          titleTooltip: 'Track Class Allocations',
          fixedWidthPx: scaleByFontFactor(55.0),
          alignment: ColumnAlignment.left,
        );

  @override
  int getValue(ClassHeapDetailStats dataObject) =>
      dataObject.isStacktraced ? 1 : 0;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  Widget build(
    BuildContext context,
    ClassHeapDetailStats item, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final controller = Provider.of<MemoryController>(context);

    return Checkbox(
      value: item.isStacktraced,
      onChanged: (value) {
        controller.toggleAllocationTracking(item, value!);
      },
    );
  }
}

class FieldClassName extends ColumnData<ClassHeapDetailStats> {
  FieldClassName() : super('Class', fixedWidthPx: scaleByFontFactor(200.0));

  @override
  String? getValue(ClassHeapDetailStats dataObject) => dataObject.classRef.name;

  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a)!;
    final Comparable valueB = getValue(b)!;
    return valueA.compareTo(valueB);
  }
}

class FieldInstanceCountColumn extends ColumnData<ClassHeapDetailStats> {
  FieldInstanceCountColumn()
      : super(
          'Instances',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(defaultNumberFieldWidth),
        );

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) =>
      dataObject.instancesCurrent;

  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class FieldInstanceDeltaColumn extends ColumnData<ClassHeapDetailStats> {
  FieldInstanceDeltaColumn()
      : super(
          'Delta',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(defaultNumberFieldWidth),
        );

  @override
  int getValue(ClassHeapDetailStats dataObject) => dataObject.instancesDelta;

  // TODO(terry): Only show grows (negative value returns 0). Consider setting
  //              to display growth and decline.
  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${max(0, getValue(dataObject))}';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class FieldSizeColumn extends ColumnData<ClassHeapDetailStats> {
  FieldSizeColumn()
      : super(
          'Bytes',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(defaultNumberFieldWidth),
        );

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) => dataObject.bytesCurrent;

  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class FieldSizeDeltaColumn extends ColumnData<ClassHeapDetailStats> {
  FieldSizeDeltaColumn()
      : super(
          'Delta',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(defaultNumberFieldWidth),
        );

  @override
  int getValue(ClassHeapDetailStats dataObject) => dataObject.bytesDelta;

  // TODO(terry): Only show grows (negative value returns 0). Consider setting
  //              to display growth and decline.
  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${max(0, getValue(dataObject))}';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}
