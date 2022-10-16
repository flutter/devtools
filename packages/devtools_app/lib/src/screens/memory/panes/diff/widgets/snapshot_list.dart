// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/theme.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

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
        final clearAllEnabled = !isProcessing && controller.hasSnapshots;
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

class _SnapshotListTitle extends StatelessWidget {
  const _SnapshotListTitle({
    Key? key,
    required this.item,
    required this.selected,
  }) : super(key: key);

  final SnapshotItem item;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theItem = item;
    return ValueListenableBuilder<bool>(
      valueListenable: theItem.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          const SizedBox(width: denseRowSpacing),
          if (theItem is SnapshotInstanceItem)
            Expanded(
              child: Text(theItem.name, overflow: TextOverflow.ellipsis),
            ),
          if (theItem is SnapshotDocItem)
            const Expanded(
              child: Text('Snapshots', overflow: TextOverflow.ellipsis),
            ),
          if (isProcessing) ...[
            Progress(),
            const SizedBox(width: denseRowSpacing)
          ],
        ],
      ),
    );
  }
}

class _SnapshotListItems extends StatefulWidget {
  const _SnapshotListItems({required this.controller});

  final DiffPaneController controller;

  @override
  State<_SnapshotListItems> createState() => _SnapshotListItemsState();
}

class _SnapshotListItemsState extends State<_SnapshotListItems>
    with AutoDisposeMixin {
  final _headerHeight = 1.20 * defaultRowHeight;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _init();
  }

  @override
  void didUpdateWidget(covariant _SnapshotListItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _init();
  }

  void _init() {
    cancelListeners();
    addAutoDisposeListener(
      widget.controller.core.selectedSnapshotIndex,
      scrollIfLast,
    );
  }

  Future<void> scrollIfLast() async {
    final core = widget.controller.core;

    final newLength = core.snapshots.value.length;
    final newIndex = core.selectedSnapshotIndex.value;

    if (newIndex == newLength - 1) await _scrollController.autoScrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.controller.core;

    return DualValueListenableBuilder<List<SnapshotItem>, int>(
      firstListenable: core.snapshots,
      secondListenable: core.selectedSnapshotIndex,
      builder: (_, snapshots, selectedIndex, __) => ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: snapshots.length,
        itemBuilder: (context, index) {
          return Container(
            height: _headerHeight,
            color: selectedIndex == index
                ? Theme.of(context).colorScheme.selectedRowColor
                : null,
            child: InkWell(
              canRequestFocus: false,
              onTap: () => widget.controller.setSnapshotIndex(index),
              child: _SnapshotListTitle(
                item: snapshots[index],
                selected: index == selectedIndex,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
