// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../shared/heap/heap.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/heap_diff.dart';
import '../controller/item_controller.dart';
import 'class_details.dart';
import 'classes_single.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.selectedSnapshotItem as SnapshotInstanceItem;
    return ValueListenableBuilder<bool>(
      valueListenable: item.isProcessing,
      builder: (_, isProcessing, __) {
        if (isProcessing) return const SizedBox.shrink();

        late HeapClasses? classes;
        if (item.diffWith.value == null) {
          classes = item.heap?.classes;
        } else {
          final heap1 = item.heap!;
          final heap2 = item.diffWith.value!.heap!;

          // TODO(polina-c): make comparison async.
          classes = controller.diffStore.compare(heap1, heap2);
        }

        if (classes == null) {
          return const Center(child: Text('Could not take snapshot.'));
        }

        if (classes is SingeHeapClasses) {
          return ValueListenableBuilder<SnapshotInstanceItem?>(
            valueListenable: item.diffWith,
            builder: (_, diffWith, __) {
              return Split(
                axis: Axis.vertical,
                initialFractions: const [0.4, 0.6],
                minSizes: const [80, 80],
                children: [
                  OutlineDecoration(
                    child: SingleClassesTable(
                      // The key is passed to persist state.
                      key: ObjectKey(item),
                      controller: controller,
                    ),
                  ),
                  const OutlineDecoration(
                    child: HeapClassDetails(
                        // item: item,
                        // sorting: controller.pathSorting,
                        ),
                  ),
                ],
              );
            },
          );
        }

        if (classes is DiffHeapClasses) {
          return const Text('heap diff classes will be here');
        }

        throw StateError('Unexpected type: ${classes.runtimeType}.');
      },
    );
  }
}
