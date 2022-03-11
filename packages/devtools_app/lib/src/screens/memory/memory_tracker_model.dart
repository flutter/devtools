// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'memory_allocation_table_view.dart';
import 'memory_controller.dart';

/// Space between items in the call stack list.
const defaultSpacerHeight = 12.0;

class Tracker extends TreeNode<Tracker> {
  factory Tracker({required String className}) {
    return Tracker._internal(name: className);
  }

  Tracker._internal({required this.name});

  /// Used for both class name and call stack entry value.
  final String name;

  @override
  Tracker shallowCopy() {
    throw UnimplementedError('This method is not implemented. Implement if you '
        'need to call `shallowCopy` on an instance of this class.');
  }
}

class TrackerClass extends Tracker {
  TrackerClass(String className) : super._internal(name: className);

  @override
  String toString() => name;
}

class TrackerAllocation extends Tracker {
  TrackerAllocation(this.timestamp, this.stacktrace)
      : super._internal(name: '');

  final int? timestamp;

  /// Sources and callstack for an instance.
  final AllocationStackTrace stacktrace;

  @override
  String toString() => '$timestamp';
}

class TrackerCall extends Tracker {
  TrackerCall(String entry) : super._internal(name: entry);

  @override
  String toString() => name;
}

class _TrackerClassColumn extends TreeColumnData<Tracker> {
  _TrackerClassColumn() : super('Tracking');

  @override
  dynamic getValue(Tracker dataObject) {
    if (dataObject is TrackerClass) {
      final TrackerClass trackerClass = dataObject;
      return trackerClass.name;
    } else if (dataObject is TrackerCall) {
      final TrackerCall call = dataObject;
      return call.name;
    } else if (dataObject is TrackerAllocation) {
      final TrackerAllocation allocation = dataObject;
      return 'Instance ${dataObject.index} @ ${prettyTimestamp(allocation.timestamp)}';
    }

    assert(false, 'Unknown dataObject');
  }

  @override
  int compare(Tracker a, Tracker b) {
    Comparable valueA = getValue(a);
    Comparable valueB = getValue(b);
    if (a is TrackerCall) {
      // Sort is always by child index for the stacktrace, call stack should not reorder.
      valueA = a.parent!.children.indexOf(a);
      valueB = b.parent!.children.indexOf(b);
    }
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 300;

  @override
  bool get supportsSorting => true;
}

class _TrackerCountColumn extends ColumnData<Tracker> {
  _TrackerCountColumn()
      : super(
          'Count',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  @override
  String getValue(Tracker dataObject) {
    if (dataObject is TrackerClass) {
      return '${dataObject.children.length}';
    }

    assert(dataObject is TrackerAllocation || dataObject is TrackerCall);
    return '';
  }

  @override
  double get fixedWidthPx => 100.0;

  @override
  bool get supportsSorting => true;
}

class TreeTracker {
  late TrackerClass tree1;

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

      final trackedClassId = classesTracked[className]!.id;

      final allocationSample = allocationSamples.singleWhereOrNull((sample) {
        // If no stacktraces, then nothing to handle.
        if (sample.totalStacktraces == 0) return false;

        // Match the sample to the class being tracked.
        final allocationClassRef = sample.classRef!;
        final allocationClassId = allocationClassRef.id;
        return allocationClassId == trackedClassId;
      });

      if (allocationSample != null) {
        for (var stacktrace in allocationSample.stacktraces) {
          final allocation = TrackerAllocation(
            stacktrace.timestamp,
            stacktrace,
          );
          classEntry.addChild(allocation);
        }
      }
    }
  }

  Widget allocationTrackingInstructions(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('To track allocations for a class, enable the '
            'checkbox for that class in the table above.'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('After interacting with your app, come '
                'back to this tool and click the track button '),
            trackImage(context),
          ],
        ),
        const Text('to view the collected stack '
            'traces of constructor calls.'),
      ],
    );
  }

  Widget allocationCallStackInstructions(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('Select an instance of a tracked class'),
          Text('to view its allocation stack trace.'),
        ],
      );

  // TODO(terry): Move to a class derived from widget.
  Widget displaySelectedStackTrace(
    BuildContext context,
    MemoryController controller,
    ScrollController scroller,
    TrackerAllocation tracker,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final allocationStacktrace = tracker.stacktrace;

    final stackTrace = allocationStacktrace.stacktrace;
    final sources = allocationStacktrace.sources;
    final callstackLength = stackTrace.length;
    assert(sources.length == callstackLength);

    final titleBackground = Theme.of(context).titleSolidBackgroundColor;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: defaultRowHeight + 4, // From table.dart
          child: Container(
              color: titleBackground,
              child: Align(
                child: Text(
                  '${tracker.parent!.name} Call Stack for Instance ${tracker.index} @ '
                  '${prettyTimestamp(tracker.timestamp!)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(backgroundColor: titleBackground),
                ),
              )),
        ),
        Expanded(
          child: Scrollbar(
            isAlwaysShown: true,
            controller: scroller,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              controller: scroller,
              itemCount: callstackLength,
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$index ${stackTrace[index]}',
                    style: colorScheme.stackTraceCall,
                  ),
                  Text(sources[index]!, style: colorScheme.stackTraceSource),
                ],
              ),
              separatorBuilder: (context, index) => Divider(
                color: devtoolsGrey[400],
                height: defaultSpacerHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const trackInstancesViewWidth = 200.0;
  static const callstackViewWidth = 280.0;

  // TODO(terry): Move to a class derived from widget.
  Widget createTrackingTable(
    BuildContext context,
    MemoryController controller,
    ScrollController scroller,
  ) {
    final selection = selectionNotifier.value;
    final trackerAllocation =
        selection.node is TrackerAllocation ? selection.node : null;

    final widget = controller.trackAllocations.isEmpty
        ? allocationTrackingInstructions(context)
        : Split(
            initialFractions: const [0.5, 0.5],
            minSizes: const [trackInstancesViewWidth, callstackViewWidth],
            axis: Axis.horizontal,
            children: [
              TreeTable<Tracker>(
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
              ),
              trackerAllocation == null
                  ? allocationCallStackInstructions(context)
                  : displaySelectedStackTrace(
                      context,
                      controller,
                      scroller,
                      trackerAllocation as TrackerAllocation,
                    ),
            ],
          );

    return widget;
  }
}
