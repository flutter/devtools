// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/utils.dart';
import 'memory_controller.dart';
import 'memory_snapshot_models.dart';

class InstanceTreeView extends StatefulWidget {
  @override
  InstanceTreeViewState createState() => InstanceTreeViewState();
}

/// Table of the fields of an instance (type, name and value).
class InstanceTreeViewState extends State<InstanceTreeView>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, InstanceTreeView> {
  final TreeColumnData<FieldReference> treeColumn = _FieldTypeColumn();

  final List<ColumnData<FieldReference>> columns = [];

  @override
  void initState() {
    super.initState();

    // Setup table column names for instance viewer.
    columns.addAll([
      treeColumn,
      _FieldNameColumn(),
      _FieldValueColumn(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    // TODO(terry): setState should be called to set our state not change the
    //              controller. Have other ValueListenables on controller to
    //              listen to, so we don't need the setState calls.
    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    controller.instanceFieldsTreeTable = TreeTable<FieldReference>(
      keyFactory: (typeRef) => PageStorageKey<String>(typeRef.name),
      dataRoots: controller.instanceRoot!,
      dataKey: 'memory-instance-tree',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: columns[0],
      defaultSortDirection: SortDirection.ascending,
    );

    return controller.instanceFieldsTreeTable!;
  }
}

class _FieldTypeColumn extends TreeColumnData<FieldReference> {
  _FieldTypeColumn() : super('Type');

  @override
  String getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference || dataObject.isSentinelReference
          ? ''
          : dataObject.type ?? '';

  @override
  String getDisplayValue(FieldReference dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final valueA = getValue(a);
    final valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 250.0;
}

class _FieldNameColumn extends ColumnData<FieldReference> {
  _FieldNameColumn()
      : super(
          'Name',
          fixedWidthPx: scaleByFontFactor(150.0),
        );

  @override
  String getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference ? '' : dataObject.name;

  @override
  String getDisplayValue(FieldReference dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final valueA = getValue(a);
    final valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class _FieldValueColumn extends ColumnData<FieldReference> {
  _FieldValueColumn()
      : super(
          'Value',
          fixedWidthPx: scaleByFontFactor(350.0),
        );

  @override
  String getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference || dataObject.isSentinelReference
          ? ''
          : dataObject.value ?? '';

  @override
  String getDisplayValue(FieldReference dataObject) {
    if (dataObject is ObjectFieldReference && !dataObject.isNull) {
      // Real object that isn't Null value is empty string.
      return '';
    }

    // TODO(terry): Can we use standard Flutter string truncation?
    //              Long variable names the beginning and end of the name is
    //              most significant the middle part of name less so.  However,
    //              we need a nice hover/tooltip to show the entire name.
    //              If middle, '...' then we need a more robust computation w/
    //              text measurement so we accurately truncate the correct # of
    //              characters instead guessing that we only show 30 chars.
    var value = getValue(dataObject);
    if (value.length > 30) {
      value = '${value.substring(0, 13)}…${value.substring(value.length - 17)}';
    }
    return '$value';
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final valueA = getValue(a);
    final valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}
