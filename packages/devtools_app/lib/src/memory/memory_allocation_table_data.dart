// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import '../table_data.dart';
import 'memory_protocol.dart';

const defaultNumberFieldWidth = 100.0;

class FieldClassName extends ColumnData<ClassHeapDetailStats> {
  FieldClassName() : super('Class');

  @override
  String getValue(ClassHeapDetailStats dataObject) => dataObject.classRef.name;

  @override
  String getDisplayValue(ClassHeapDetailStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapDetailStats a, ClassHeapDetailStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 200.0;
}

class FieldInstanceCountColumn extends ColumnData<ClassHeapDetailStats> {
  FieldInstanceCountColumn()
      : super(
          'Instances',
          alignment: ColumnAlignment.right,
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

  @override
  double get fixedWidthPx => defaultNumberFieldWidth;
}

class FieldInstanceDeltaColumn extends ColumnData<ClassHeapDetailStats> {
  FieldInstanceDeltaColumn()
      : super(
          'Delta',
          alignment: ColumnAlignment.right,
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

  @override
  double get fixedWidthPx => defaultNumberFieldWidth;
}

class FieldSizeColumn extends ColumnData<ClassHeapDetailStats> {
  FieldSizeColumn()
      : super(
          'Bytes',
          alignment: ColumnAlignment.right,
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

  @override
  double get fixedWidthPx => defaultNumberFieldWidth;
}

class FieldSizeDeltaColumn extends ColumnData<ClassHeapDetailStats> {
  FieldSizeDeltaColumn()
      : super(
          'Delta',
          alignment: ColumnAlignment.right,
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

  @override
  double get fixedWidthPx => defaultNumberFieldWidth;
}
