// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'memory_allocation_table_data.dart';
import 'memory_controller.dart';
import 'memory_protocol.dart';

class AllocationTableView extends StatefulWidget {
  @override
  AllocationTableViewState createState() => AllocationTableViewState();
}

/// Table of the fields of an instance (type, name and value).
class AllocationTableViewState extends State<AllocationTableView>
    with AutoDisposeMixin {
  MemoryController controller;

  final List<ColumnData<ClassHeapDetailStats>> columns = [];

  @override
  void initState() {
    super.initState();

    // Setup the columns.
    columns.addAll([
      FieldClassName(),
      FieldInstanceCountColumn(),
      FieldInstanceDeltaColumn(),
      FieldSizeColumn(),
      FieldSizeDeltaColumn(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

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
    if (controller.allocationsFieldsTable == null) {
      controller.sortedMonitorColumn = columns[0];
      controller.sortedMonitorDirection = SortDirection.ascending;
    }

    controller.allocationsFieldsTable = FlatTable<ClassHeapDetailStats>(
      columns: columns,
      data: controller.monitorAllocations,
      keyFactory: (d) => Key(d.classRef.name),
      onItemSelected: (ref) {},
      sortColumn: controller.sortedMonitorColumn,
      sortDirection: controller.sortedMonitorDirection,
      onSortChanged: (column, direction) {
        controller.sortedMonitorColumn = column;
        controller.sortedMonitorDirection = direction;
      },
    );

    return controller.allocationsFieldsTable;
  }
}
