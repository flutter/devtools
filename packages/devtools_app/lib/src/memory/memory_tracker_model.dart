// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../table.dart';
import '../table_data.dart';
import '../trees.dart';
import '../utils.dart';
import 'memory_controller.dart';

class Tracker extends TreeNode<Tracker> {
  factory Tracker({String className}) {
    return Tracker._internal(name: className);
  }

  Tracker._internal({this.name});

  /// Used for both class name and call stack entry value.
  final String name;
}

class TrackerClass extends Tracker {
  TrackerClass(String className) : super._internal(name: className);

  @override
  String toString() => name;
}

class TrackerAllocation extends Tracker {
  TrackerAllocation(this.timestamp) : super._internal(name: null);

  final int timestamp;

  bool displayAll = false;

  /// If displayAll is false then depth of callstack is:
  final callDepthDisplay = 4;

  @override
  String toString() => '$timestamp';
}

class TrackerCall extends Tracker {
  TrackerCall(String entry) : super._internal(name: entry);

  @override
  String toString() => name;
}

class TrackerMore extends Tracker {
  TrackerMore(this.stacktrace) : super._internal(name: 'More ...');

  final List<String> stacktrace;

  @override
  String toString() => name;
}

class _TrackerClassColumn extends TreeColumnData<Tracker> {
  _TrackerClassColumn() : super('Tracking');

  @override
  dynamic getValue(Tracker dataObject) {
    if (dataObject is TrackerClass || dataObject is TrackerMore) {
      return dataObject.name;
    } else if (dataObject is TrackerCall) {
      final TrackerCall call = dataObject;
      return call.name;
    } else if (dataObject is TrackerAllocation) {
      final TrackerAllocation allocation = dataObject;
      return '${dataObject.parent.name} @ ${prettyTimestamp(allocation.timestamp)}';
    }

    assert(false, 'Unknown dataObject');
  }

  @override
  int compare(Tracker a, Tracker b) {
    Comparable valueA = getValue(a);
    Comparable valueB = getValue(b);
    if (a is TrackerCall) {
      // Sort is always by child index for the stacktrace, call stack should not reorder.
      valueA = a.parent.children.indexOf(a);
      valueB = b.parent.children.indexOf(b);
    }
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 640;

  @override
  bool get supportsSorting => true;
}

class _TrackerCountColumn extends ColumnData<Tracker> {
  _TrackerCountColumn()
      : super(
          'Count',
          alignment: ColumnAlignment.right,
          fixedWidthPx: 100.0,
        );

  @override
  String getValue(Tracker dataObject) {
    if (dataObject is TrackerClass) {
      return '${dataObject.children.length}';
    }

    assert(dataObject is TrackerAllocation ||
        dataObject is TrackerCall ||
        dataObject is TrackerMore);
    return '';
  }

  @override
  double get fixedWidthPx => 50.0;

  @override
  bool get supportsSorting => true;
}

class TreeTracker {
  TrackerClass tree1;

  TreeColumnData<Tracker> treeColumn = _TrackerClassColumn();

  final selectionNotifier =
      ValueNotifier<Selection<Tracker>>(Selection<Tracker>());

  /// Rebuild list of classes to track.
  void createTrackerTree(
    Map<String, ClassRef> classesTracked,
    List<AllocationSamples> allocationSamples,
  ) {
    tree1 = TrackerClass('_ROOT_tracking');

    tree1.children.clear();

    final classesName = classesTracked.keys;
    for (var className in classesName) {
      final classEntry = TrackerClass(className);
      tree1.addChild(classEntry);

      final trackedClassId = classesTracked[className].id;

      final allocationSample = allocationSamples.singleWhere((sample) {
        // If no stacktraces, then nothing to handle.
        if (sample.totalStacktraces == 0) return false;

        // Match the sample to the class being tracked.
        final allocationClassRef = sample.classRef;
        final allocationClassId = allocationClassRef.id;
        return allocationClassId == trackedClassId;
      }, orElse: () => null);

      if (allocationSample != null) {
        for (var stacktrace in allocationSample.stacktraces) {
          final allocation = TrackerAllocation(stacktrace.timestamp);
          classEntry.addChild(allocation);
          int displayDepth = 0;
          for (var callStackEntry in stacktrace.stacktrace) {
            if (allocation.displayAll ||
                displayDepth++ < allocation.callDepthDisplay) {
              allocation.addChild(TrackerCall(callStackEntry));
            }
          }
          if (!allocation.displayAll) {
            allocation.addChild(TrackerMore(stacktrace.stacktrace));
          }
        }
      }
    }
  }

  /// Remove the "More ..." and show the entire call stack.
  void expandCallStack(TrackerMore item) {
    final TrackerAllocation allocation = item.parent;

    // Show the entire call stack for this instance.
    allocation.displayAll = true;

    // Re-construct the callstack for this instance.
    final leafNodesCount = allocation.children.length;

    assert(allocation.children.last is TrackerMore);
    allocation.removeLastChild(); // Remove "More ..."

    // Add the entire call stack as leaf nodes.
    final totalCallStack = item.stacktrace.length;
    for (var index = leafNodesCount - 1; index < totalCallStack; index++) {
      allocation.addChild(TrackerCall(item.stacktrace[index]));
    }
    allocation.expandCascading();
  }

  Widget createTrackingTable(MemoryController controller) {
    final widget = controller.trackAllocations.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 15),
            child: Text('No classes tracked.', textAlign: TextAlign.center),
          )
        : TreeTable<Tracker>(
            columns: [
              treeColumn,
              _TrackerCountColumn(),
            ],
            dataRoots: tree1.children,
            treeColumn: treeColumn,
            keyFactory: (d) {
              return Key(d.name);
            },
            sortColumn: treeColumn,
            sortDirection: SortDirection.ascending,
            selectionNotifier: selectionNotifier,
          );
    return widget;
  }
}
