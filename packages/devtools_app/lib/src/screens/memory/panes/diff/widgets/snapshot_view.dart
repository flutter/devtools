// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';
import 'class_details/class_details.dart';
import 'class_filter.dart';
import 'classes_table_diff.dart';
import 'classes_table_single.dart';

class SnapshotView extends StatefulWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  State<SnapshotView> createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<SnapshotView> {
  @override
  void initState() {
    super.initState();
    _initStaticFields(widget.controller);
  }

  @override
  void didUpdateWidget(SnapshotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DiffPaneController newController = widget.controller;
    if (oldWidget.controller == newController) return;
    _initStaticFields(newController);
  }

  static void _initStaticFields(DiffPaneController controller) {
    SingleInstanceColumn.heapOpbtainer =
        () => (controller.core.selectedItem as SnapshotInstanceItem).heap!.data;

    SingleRetainedSizeColumn.totalSizeObtainer =
        () => (controller.core.selectedItem as SnapshotInstanceItem).totalSize!;

    SingleClassNameColumn.classFilterButton =
        DiffClassNameColumn.classFilterButton = ClassFilterButton(
      filter: controller.core.classFilter,
      onChanged: controller.applyFilter,
      rootPackage: serviceManager.rootInfoNow().package,
    );

    ClassesTableDiff.sizeTypeToShowForDiff = controller.sizeTypeToShowForDiff;

    final diffHeapClasses = controller.derived.heapClasses;
    DiffInstanceColumn.before =
        () => (diffHeapClasses.value as DiffHeapClasses).before;
    DiffInstanceColumn.after =
        () => (diffHeapClasses.value as DiffHeapClasses).after;
  }

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<List<SingleClassStats>?,
        List<DiffClassStats>?>(
      firstListenable: widget.controller.derived.singleClassesToShow,
      secondListenable: widget.controller.derived.diffClassesToShow,
      builder: (_, singleClasses, diffClasses, __) {
        if (widget.controller.derived.updatingValues) {
          return const Center(child: Text('Calculating...'));
        }

        final classes = widget.controller.derived.heapClasses.value;
        if (classes == null) {
          return widget.controller.isTakingSnapshot.value
              ? const SizedBox.shrink()
              : const Center(child: Text('Could not take snapshot.'));
        }

        assert((singleClasses == null) != (diffClasses == null));

        late Widget classTable;

        if (singleClasses != null) {
          classTable = ClassesTableSingle(
            classes: singleClasses,
            selection: widget.controller.derived.selectedSingleClassStats,
          );
        } else if (diffClasses != null) {
          classTable = ClassesTableDiff(
            classes: widget.controller.derived.diffClassesToShow.value!,
            selection: widget.controller.derived.selectedDiffClassStats,
          );
        } else {
          throw StateError('singleClasses or diffClasses should not be null.');
        }

        final pathTable = ValueListenableBuilder<List<StatsByPathEntry>?>(
          valueListenable: widget.controller.derived.pathEntries,
          builder: (_, entries, __) => HeapClassDetails(
            entries: entries,
            selection: widget.controller.derived.selectedPathEntry,
            isDiff: classes is DiffHeapClasses,
            pathController: widget.controller.retainingPathController,
            className: widget.controller.core.className_?.className,
          ),
        );

        return Split(
          axis: Axis.vertical,
          initialFractions: const [0.4, 0.6],
          minSizes: const [80, 80],
          children: [
            OutlineDecoration.onlyBottom(
              child: classTable,
            ),
            OutlineDecoration.onlyTop(
              child: pathTable,
            ),
          ],
        );
      },
    );
  }
}
