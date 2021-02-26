// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../ui/icons.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'memory_allocation_table_data.dart';
import 'memory_controller.dart';
import 'memory_tracker_model.dart';

// Track Image.
Image trackImage(BuildContext context) {
  final themeData = Theme.of(context);
  // TODO(terry): Match shape in event pane.
  return createImageIcon(
    themeData.isDarkTheme
        ? 'icons/memory/communities_white.png'
        : 'icons/memory/communities_black.png',
  );
}

Image resetImage(BuildContext context) {
  final themeData = Theme.of(context);

  return createImageIcon(
    // TODO(terry): Match shape in event pane.
    themeData.isDarkTheme
        ? 'icons/memory/reset_icon_white.png'
        : 'icons/memory/reset_icon_black.png',
  );
}

class AllocationTableView extends StatefulWidget {
  const AllocationTableView() : super(key: allocationTableKey);

  @visibleForTesting
  static const allocationTableKey = Key('Allocation Table');

  @override
  AllocationTableViewState createState() => AllocationTableViewState();
}

/// Table of the fields of an instance (type, name and value).
class AllocationTableViewState extends State<AllocationTableView>
    with AutoDisposeMixin {
  AllocationTableViewState() : super();

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

    addAutoDisposeListener(controller.selectTheSearchNotifier, _handleSearch);

    addAutoDisposeListener(controller.searchNotifier, _handleSearch);
  }

  void _handleSearch() {
    if (_trySelectItem()) {
      setState(() {
        controller.closeAutoCompleteOverlay();
      });
    }
  }

  /// Search the allocation data for a match (auto-complete).
  List<String> _allocationMatches(String searchingValue) {
    final matches = <String>[];

    // Matches that start with searchingValue, most relevant.
    final startMatches = <String>[];

    // TODO(terry): Consider matches using the starts and the containing are added
    //              at end using addAll().  Also, should not build large list just
    //              up to max needed.
    for (var allocation in controller.monitorAllocations) {
      final knownName = allocation.classRef.name;
      if (knownName.startsWith(searchingValue)) {
        startMatches.add(knownName);
      } else if (knownName.contains(searchingValue.toLowerCase())) {
        matches.add(knownName);
      }
    }

    matches.insertAll(0, startMatches);
    return matches;
  }

  bool _trySelectItem() {
    final searchingValue = controller.search;
    if (searchingValue.isNotEmpty) {
      if (controller.selectTheSearch) {
        // Found an exact match.
        controller.selectItemInAllocationTable(searchingValue);
        controller.selectTheSearch = false;
        controller.resetSearch();
        return true;
      }

      // No exact match, return the list of possible matches.
      controller.clearSearchAutoComplete();

      final matches = _allocationMatches(searchingValue);

      // Remove duplicates and sort the matches.
      final sortedAllocationMatches = matches.toSet().toList()..sort();
      // Use the top 10 matches:
      controller.searchAutoComplete.value = sortedAllocationMatches.sublist(
        0,
        min(topMatchesLimit, sortedAllocationMatches.length),
      );
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (controller.allocationsFieldsTable == null) {
      // Sort by class name.
      controller.sortedMonitorColumn = columns[1];
      controller.sortedMonitorDirection = SortDirection.ascending;
    }

    if (controller.monitorAllocations.isEmpty) {
      // Display help text on how to monitor classes constructed.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Click the track button '),
              trackImage(context),
              const Text(
                ' to begin monitoring changes in '
                'memory instances (classes constructed).',
              ),
            ],
          ),
        ],
      );
    }

    controller.searchMatchMonitorAllocationsNotifier.value = null;

    controller.allocationsFieldsTable = FlatTable<ClassHeapDetailStats>(
      columns: columns,
      data: controller.monitorAllocations,
      keyFactory: (d) => Key(d.classRef.name),
      onItemSelected: (ref) =>
          controller.toggleAllocationTracking(ref, !ref.isStacktraced),
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
      initialFractions: const [0.8, 0.2],
      minSizes: const [200, 0],
      axis: Axis.vertical,
      children: [
        controller.allocationsFieldsTable,
        trackerData.createTrackingTable(controller),
      ],
    );
  }
}
