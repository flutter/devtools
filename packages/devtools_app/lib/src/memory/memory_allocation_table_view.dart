// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../utils.dart';
import 'memory_allocation_table_data.dart';
import 'memory_controller.dart';
import 'memory_protocol.dart';
import 'memory_tracker_model.dart';

class AllocationTableView extends StatefulWidget {
  @override
  AllocationTableViewState createState() => AllocationTableViewState();
}

/// Table of the fields of an instance (type, name and value).
class AllocationTableViewState extends State<AllocationTableView>
    with AutoDisposeMixin {
  MemoryController controller;

  final List<ColumnData<ClassHeapDetailStats>> columns = [];

  var samplesProcessed = <ClassRef, CpuSamples>{};

  final trackerData = TreeTracker();

  @override
  void initState() {
    super.initState();

    // Setup the columns.
    columns.addAll([
      FieldTrack(),
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

    addAutoDisposeListener(controller.updateClassStackTraces, () {
      setState(() {
        trackerData.createTrackerTree(
          controller.trackAllocations,
          controller.allocationSamples,
        );
      });
    });

    addAutoDisposeListener(controller.treeChangedNotifier, () {
      setState(() {});
    });

    addAutoDisposeListener(trackerData.selectionNotifier, () {
      final Tracker item = trackerData.selectionNotifier.value.node;
      if (item is TrackerMore) trackerData.expandCallStack(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller.allocationsFieldsTable == null) {
      // Sort by class name.
      controller.sortedMonitorColumn = columns[1];
      controller.sortedMonitorDirection = SortDirection.ascending;
    }

    if (controller.monitorAllocations.isEmpty) {
      return const SizedBox(height: defaultSpacing);
    }

    controller.searchMatchMonitorAllocationsNotifier.value = null;

    controller.allocationsFieldsTable = FlatTable<ClassHeapDetailStats>(
      columns: columns,
      data: controller.monitorAllocations,
      keyFactory: (d) => Key(d.classRef.name),
      onItemSelected: (ref) {},
      sortColumn: controller.sortedMonitorColumn,
      sortDirection: controller.sortedMonitorDirection,
      onSortChanged: (
        column,
        direction,
      ) {
        controller.sortedMonitorColumn = column;
        controller.sortedMonitorDirection = direction;
      },
      activeSearchMatchNotifier:
          controller.searchMatchMonitorAllocationsNotifier,
    );

    return Split(
      initialFractions: const [0.9, 0.1],
      minSizes: const [200, 0],
      axis: Axis.vertical,
      children: [
        controller.allocationsFieldsTable,
        trackerData.createTrackingTable(controller),
      ],
    );
  }
}
