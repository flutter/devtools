// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/theme.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/model.dart';

class SnapshotList extends StatelessWidget {
  const SnapshotList({Key? key, required this.controller}) : super(key: key);
  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ListControlPane(controller: controller),
        Expanded(
          child: _SnapshotListItems(controller: controller),
        ),
      ],
    );
  }
}

class _ListControlPane extends StatelessWidget {
  const _ListControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isProcessing,
      builder: (_, isProcessing, __) {
        final takeSnapshotEnabled = !isProcessing;
        final clearAllEnabled = !isProcessing & controller.hasSnapshots;
        return Row(
          children: [
            ToolbarAction(
              icon: Icons.fiber_manual_record,
              tooltip: 'Take heap snapshot for the selected isolate',
              onPressed: takeSnapshotEnabled ? controller.takeSnapshot : null,
            ),
            ToolbarAction(
              icon: Icons.block,
              tooltip: 'Clear all snapshots',
              onPressed: clearAllEnabled ? controller.clearSnapshots : null,
            )
          ],
        );
      },
    );
  }
}

class _SnapshotListItems extends StatelessWidget {
  _SnapshotListItems({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;
  final headerHeight = 1.20 * defaultRowHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller.listScrollController,
      shrinkWrap: true,
      itemCount: controller.snapshots.value.length,
      itemBuilder: (context, index) {
        return Container(
          height: headerHeight,
          color: controller.selectedIndex.value == index
              ? Theme.of(context).selectedRowColor
              : null,
          child: InkWell(
            canRequestFocus: false,
            onTap: () => controller.selectedIndex.value = index,
            child: _SnapshotListTitle(
              item: controller.snapshots.value[index],
              selected: index == controller.selectedIndex.value,
            ),
          ),
        );
      },
    );
  }
}

class _SnapshotListTitle extends StatelessWidget {
  const _SnapshotListTitle({
    Key? key,
    required this.item,
    required this.selected,
  }) : super(key: key);

  final DiffListItem item;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theItem = item;
    return ValueListenableBuilder<bool>(
      valueListenable: theItem.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          const SizedBox(width: denseRowSpacing),
          if (theItem is SnapshotListItem)
            Expanded(
              child: Text(theItem.name, overflow: TextOverflow.ellipsis),
            ),
          if (theItem is InformationListItem) ...[
            const Expanded(
              child: Text('Snapshots', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: denseRowSpacing),
            const Text('ⓘ'),
            const SizedBox(width: denseRowSpacing),
          ],
          if (isProcessing) ...[
            Progress(),
            const SizedBox(width: denseRowSpacing)
          ],
        ],
      ),
    );
  }
}
