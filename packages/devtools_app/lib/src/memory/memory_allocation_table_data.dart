// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../table_data.dart';
import '../trees.dart';
import 'memory_protocol.dart';

/*
class AllocationData extends TreeNode<AllocationData> {
  AllocationData(this.className, this.instanceCount, this.instanceAccumulator,
      this.bytes, this.bytesAccumulator);

  final String className;
  final int instanceCount;
  final int instanceAccumulator;
  final int bytes;
  final int bytesAccumulator;

  @override
  String toString() =>
      '$className - $instanceCount,$instanceAccumulator [$bytes, $bytesAccumulator]';
}
*/

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
  double get fixedWidthPx => 150.0;
}

class FieldInstanceAccumulatorColumn extends ColumnData<ClassHeapDetailStats> {
  FieldInstanceAccumulatorColumn()
      : super(
          'Accum',
          alignment: ColumnAlignment.right,
        );

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) =>
      dataObject.instancesAccumulated;

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
  double get fixedWidthPx => 150.0;
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
  double get fixedWidthPx => 150.0;
}

class FieldSizeAccumulatorColumn extends ColumnData<ClassHeapDetailStats> {
  FieldSizeAccumulatorColumn()
      : super(
          'Accum',
          alignment: ColumnAlignment.right,
        );

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) =>
      dataObject.bytesAccumulated;

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
  double get fixedWidthPx => 150.0;
}
