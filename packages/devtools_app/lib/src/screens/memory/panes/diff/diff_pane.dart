// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import '../../../../shared/theme.dart';
import 'controller/diff_pane_controller.dart';
import 'controller/item_controller.dart';
import 'widgets/snapshot_control_pane.dart';
import 'widgets/snapshot_list.dart';
import 'widgets/snapshot_view.dart';

class DiffPane extends StatelessWidget {
  const DiffPane({Key? key, required this.diffController}) : super(key: key);

  final DiffPaneController diffController;

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.1, 0.9],
      minSizes: const [80, 80],
      children: [
        OutlineDecoration(
          child: SnapshotList(controller: diffController),
        ),
        OutlineDecoration(
          child: _SnapshotItemContent(
            controller: diffController,
          ),
        ),
      ],
    );
  }
}

class _SnapshotItemContent extends StatelessWidget {
  const _SnapshotItemContent({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotItem>(
      valueListenable: controller.derived.selectedItem,
      builder: (_, item, __) {
        if (item is SnapshotDocItem) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(denseSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(_snapshotDocumentation),
                  const SizedBox(height: defaultSpacing),
                  IconLabelButton(
                    onPressed: () async => await controller.takeSnapshot(),
                    icon: Icons.fiber_manual_record,
                    label: 'Take Snapshot',
                  )
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            const SizedBox(height: denseRowSpacing),
            SnapshotControlPane(controller: controller),
            const SizedBox(height: denseRowSpacing),
            Expanded(
              child: SnapshotView(
                controller: controller,
              ),
            ),
          ],
        );
      },
    );
  }
}

const _snapshotDocumentation = '''
Take a heap snapshot to view the current memory allocation details.

1. Click on the ● button in the 'Snapshots' panel to the left (or click [ ● Take Snapshot ] below these instructions)
2. Use the filter button above the snapshot table to refine the results
3. Select a class from the snapshot table to view its retaining paths in another table
4. Select a path from the 'Shortest retaining paths…' table to view the path details

View the diff between snapshots to detect or debug allocation issues for a feature.

1. Take a snapshot (1) at the starting point of the feature in your application
2. Execute the feature in your application
3. Take another snapshot (2) at the end of the feature execution
4. While viewing (2), click the 'Diff with:' dropdown menu and select (1); the results area will display the delta of (1) and (2)
6. Use the filter button as needed to refine the diff results
7. Select a class from the diff with unexpected instances to view its retaining paths, and see which objects hold the references to those instances
''';
