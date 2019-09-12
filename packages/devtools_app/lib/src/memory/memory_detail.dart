// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../table_data.dart';
import 'memory_protocol.dart';

class MemoryRow {
  MemoryRow(this.name, this.bytes, this.percentage);

  final String name;
  final int bytes;
  final double percentage;

  @override
  String toString() => name;
}

class MemoryColumnClassName extends ColumnData<ClassHeapDetailStats> {
  MemoryColumnClassName() : super.wide('Class');

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) => dataObject.classRef.name;
}

class MemoryColumnSize extends ColumnData<ClassHeapDetailStats> {
  MemoryColumnSize() : super('Size');

  @override
  bool get numeric => true;

  //String get cssClass => 'monospace';

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) => dataObject.bytesCurrent;

  @override
  String render(dynamic value) {
    if (value < 1024) {
      return ' ${ColumnData.fastIntl(value)}';
    } else {
      return ' ${ColumnData.fastIntl(value ~/ 1024)}k';
    }
  }
}

class MemoryColumnInstanceCount extends ColumnData<ClassHeapDetailStats> {
  MemoryColumnInstanceCount() : super('Count');

  @override
  bool get numeric => true;

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) =>
      dataObject.instancesCurrent;

  @override
  String render(dynamic value) => ColumnData.fastIntl(value);
}

class MemoryColumnInstanceAccumulatedCount
    extends ColumnData<ClassHeapDetailStats> {
  MemoryColumnInstanceAccumulatedCount() : super('Accumulator');

  @override
  bool get numeric => true;

  @override
  dynamic getValue(ClassHeapDetailStats dataObject) =>
      dataObject.instancesAccumulated;

  @override
  String render(dynamic value) => ColumnData.fastIntl(value);
}

class MemoryColumnSimple<T> extends ColumnData<T> {
  MemoryColumnSimple(String name, this.getter,
      {bool wide = false,
      bool usesHtml = false,
      bool hover = false,
      String cssClass})
      : super(
          name,
          usesHtml: usesHtml,
          cssClass: cssClass,
          hover: hover,
        );

  String Function(T) getter;

  @override
  String getValue(T dataObject) => getter(dataObject);
}
