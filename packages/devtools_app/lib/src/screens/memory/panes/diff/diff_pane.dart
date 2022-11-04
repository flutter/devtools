// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
          return Padding(
            padding: const EdgeInsets.all(defaultSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: Markdown(data: _snapshotDocumentation)),
                const SizedBox(height: denseSpacing),
                IconLabelButton(
                  onPressed: () async => await controller.takeSnapshot(),
                  icon: Icons.fiber_manual_record,
                  label: 'Take Snapshot',
                )
              ],
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

/// `\v` adds vertical space
const _snapshotDocumentation = '''
Take a **heap snapshot** to view current memory allocation:

1. In the Snapshots panel, click the ● button
(or click **Take Snapshot** below these instructions)
2. Use the **Filter** button to refine the results
3. Select a class from the snapshot table to view its retaining paths
4. View the path detail by selecting from the **Shortest Retaining Paths…** table

\v

Check the **diff** between snapshots to detect allocation issues:

1. Take a **snapshot**
2. Execute the feature in your application
3. Take a second snapshot
4. While viewing the second snapshot, click **Diff with:** and select the first snapshot from the drop-down menu;
the results area will display the diff
5. Use the **Filter** button to refine the diff results, if needed
6. Select a class from the diff to view its retaining paths, and see which objects hold the references to those instances
''';
