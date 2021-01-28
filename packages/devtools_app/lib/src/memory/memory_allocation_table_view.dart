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

  @override
  void initState() {
    super.initState();

    // Setup the columns.
    columns.addAll([
      FieldTrace(),
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
      setState(() {});
    });

    addAutoDisposeListener(controller.treeChangedNotifier, () {
      if (controller.isTreeChanged) {
        setState(() {});
      }
    });
  }

  /// Construct all objects tracked and their stacktraces.
  List<Widget> allTrackedCreations(ClassRef classRef) {
    final fixFontStyle = fixedFontStyle(context);

    final allocationSample = controller.allocationSamples.singleWhere(
      (element) => element.classRef.id == classRef.id,
      orElse: () => null,
    );

    // Nothing tracked.
    if (allocationSample == null) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text('empty', style: fixFontStyle),
        )
      ];
    }

    final smallerFixedFont = smallerFixedFontStyle(context);

    final subTitles = <ExpansionTile>[];

    for (var stacktrace in allocationSample.stacktraces) {
      final callStackEntries = <Widget>[];

      callStackEntries.add(Text(
        '${stacktrace.stacktraceDisplay(maxLines: stacktrace.showFullStacktrace ? -1 : 4)}',
        style: smallerFixedFont,
      ));
      if (stacktrace.stackDepth > 4 && !stacktrace.showFullStacktrace) {
        callStackEntries.add(
          InkWell(
            onTap: () {
              stacktrace.showFullStacktrace = true;
              // TODO(terry): Use a value notifier.
              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('More ...', style: smallerFixedFont),
            ),
          ),
        );
      }

      final stackTraceWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 80),
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: callStackEntries,
        ),
      );

      subTitles.add(
        ExpansionTile(
          tilePadding: const EdgeInsets.only(left: 80, right: 20),
          childrenPadding: EdgeInsets.zero,
          title: Text(
            '${allocationSample.classRef.name} '
            '@${prettyTimestamp(stacktrace.timestamp)}',
            style: fixFontStyle,
          ),
          children: [stackTraceWidget],
        ),
      );
    }

    return subTitles;
  }

  ExpansionTile _createExpansionTile(int index) {
    final fixFontStyle = fixedFontStyle(context);

    if (controller.trackAllocations.isNotEmpty) {
      // Show what is to be tracked.
      final trackingClasses = controller.trackAllocations.keys.toList();
      final className = trackingClasses[index];
      final classRef = controller.trackAllocations[className];
      final childWidgets = allTrackedCreations(classRef);
      return ExpansionTile(
        leading: const Icon(Icons.track_changes),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        childrenPadding: EdgeInsets.zero,
        title: Text(className, style: fixFontStyle),
        children: childWidgets,
      );
    } else {
      return null;
    }
  }

  Widget trackedClassesList() {
    return controller.trackAllocations.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 15),
            child: Text('No classes tracked.', textAlign: TextAlign.center),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(0),
            itemCount: controller.trackAllocations.length,
            itemBuilder: (BuildContext context, int index) =>
                _createExpansionTile(index),
          );
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

    controller.allocationsFieldsTable = FlatTable<ClassHeapDetailStats>(
      columns: columns,
      data: controller.monitorAllocations,
      keyFactory: (d) => Key(d.classRef.name),
      onItemSelected: (ref) {
        final isTraced = !ref.isStacktraced;
        ref.isStacktraced = isTraced;

        controller
            .setTracking(
              ref.classRef,
              isTraced,
            )
            .then((success) => true)
            .catchError((e) => debugLogger('ERROR: ${e.message}'))
            .whenComplete(() => controller.changeStackTraces());
      },
      sortColumn: controller.sortedMonitorColumn,
      sortDirection: controller.sortedMonitorDirection,
      onSortChanged: (
        column,
        direction,
      ) {
        controller.sortedMonitorColumn = column;
        controller.sortedMonitorDirection = direction;
      },
    );

    return Split(
      initialFractions: const [0.9, 0.1],
      minSizes: const [200, 0],
      axis: Axis.vertical,
      children: [
        controller.allocationsFieldsTable,
        trackedClassesList(),
      ],
    );
  }
}
