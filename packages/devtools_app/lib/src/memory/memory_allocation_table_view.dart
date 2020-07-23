// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/memory/memory_protocol.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'memory_allocation_table_data.dart';
import 'memory_controller.dart';

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
    setupColumns();

    super.initState();
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

  void setupColumns() {
    columns.addAll([
      FieldClassName(),
      FieldInstanceCountColumn(),
      FieldInstanceAccumulatorColumn(),
      FieldSizeColumn(),
      FieldSizeAccumulatorColumn(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ColumnData<ClassHeapDetailStats> toSortColumn;
    SortDirection toSortDirection;
    if (controller.allocationsFieldsTable != null) {
      toSortColumn = controller.allocationsFieldsTable.sortedColumn; 
      toSortDirection = controller.allocationsFieldsTable.sortedDirection;
    } else {
      toSortColumn = columns[0];
      toSortDirection = SortDirection.ascending;
    }

    controller.allocationsFieldsTable = FlatTable<ClassHeapDetailStats>(
      columns: columns,
      data: controller.monitorAllocations,
      keyFactory: (d) => Key(d.classRef.name),
      onItemSelected: (ref) {
        print(">> Table Row clicked $ref");
      },
      sortColumn: toSortColumn,
      sortDirection: toSortDirection,
    );

    return controller.allocationsFieldsTable;
  }
}
