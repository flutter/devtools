// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../vm_developer_common_widgets.dart';
import '../vm_service_private_extensions.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

abstract class _ObjectPoolColumnData extends ColumnData<ObjectPoolEntry> {
  _ObjectPoolColumnData(super.title, {required super.fixedWidthPx});
  _ObjectPoolColumnData.wide(super.title) : super.wide();

  @override
  bool get supportsSorting => false;
}

class _AddressColumn extends _ObjectPoolColumnData {
  _AddressColumn()
      : super(
          'Offset',
          fixedWidthPx: 160,
        );

  @override
  int getValue(ObjectPoolEntry dataObject) {
    return dataObject.offset;
  }

  @override
  String getDisplayValue(ObjectPoolEntry dataObject) {
    final value = getValue(dataObject);
    return '[PP + 0x${value.toRadixString(16).toUpperCase()}]';
  }
}

class _DartObjectColumn extends _ObjectPoolColumnData
    implements ColumnRenderer<ObjectPoolEntry> {
  _DartObjectColumn({required this.controller}) : super.wide('Object');

  final ObjectInspectorViewController controller;

  @override
  Object getValue(ObjectPoolEntry entry) => entry.value;

  @override
  Widget? build(
    BuildContext context,
    ObjectPoolEntry data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    if (data.value is int) return Text(data.value.toString());
    return VmServiceObjectLink(
      object: data.value as Response,
      onTap: controller.findAndSelectNodeForObject,
    );
  }
}

/// A widget for the object inspector historyViewport displaying information
/// related to [ObjectPool] objects in the Dart VM.
class VmObjectPoolDisplay extends StatelessWidget {
  const VmObjectPoolDisplay({
    super.key,
    required this.controller,
    required this.objectPool,
  });

  final ObjectInspectorViewController controller;
  final ObjectPoolObject objectPool;

  @override
  Widget build(BuildContext context) {
    return SplitPane(
      initialFractions: const [0.4, 0.6],
      axis: Axis.vertical,
      children: [
        OutlineDecoration.onlyBottom(
          child: VmObjectDisplayBasicLayout(
            controller: controller,
            object: objectPool,
            generalDataRows: vmObjectGeneralDataRows(controller, objectPool),
          ),
        ),
        OutlineDecoration.onlyTop(
          child: ObjectPoolTable(
            objectPool: objectPool,
            controller: controller,
          ),
        ),
      ],
    );
  }
}

class ObjectPoolTable extends StatelessWidget {
  ObjectPoolTable({
    super.key,
    required this.objectPool,
    required this.controller,
  });

  late final columns = <ColumnData<ObjectPoolEntry>>[
    _AddressColumn(),
    _DartObjectColumn(controller: controller),
  ];

  final ObjectInspectorViewController controller;
  final ObjectPoolObject objectPool;

  @override
  Widget build(BuildContext context) {
    return FlatTable<ObjectPoolEntry>(
      data: objectPool.obj.entries,
      dataKey: 'vm-code-display',
      keyFactory: (entry) => Key(entry.offset.toString()),
      columnGroups: [
        ColumnGroup.fromText(title: 'Entries', range: const Range(0, 2)),
      ],
      columns: columns,
      defaultSortColumn: columns[0],
      defaultSortDirection: SortDirection.ascending,
    );
  }
}
