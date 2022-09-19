// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';
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
        final showTakeSnapshot = !isProcessing;
        final showClearAll = !isProcessing & controller.hasSnapshots;
        return Row(
          children: [
            ToolbarAction(
              icon: Icons.fiber_manual_record,
              tooltip: 'Take heap snapshot for the selected isolate',
              onPressed: showTakeSnapshot ? controller.takeSnapshot : null,
            ),
            ToolbarAction(
              icon: Icons.block,
              tooltip: 'Clear all snapshots',
              onPressed: showClearAll ? controller.clearSnapshots : null,
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
            const _ProgressIndicator(),
            const SizedBox(width: denseRowSpacing)
          ],
        ],
      ),
    );
  }
}

class _SnapshotListItems extends StatefulWidget {
  const _SnapshotListItems({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  State<_SnapshotListItems> createState() => _SnapshotListItemsState();
}

class _SnapshotListItemsState extends State<_SnapshotListItems>
    with AutoDisposeMixin {
  final _headerHeight = 1.20 * defaultRowHeight;
  late ScrollController _scrollController;
  late int _currentSnapshotsLength;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _currentSnapshotsLength = widget.controller.snapshots.value.length;
    addAutoDisposeListener(widget.controller.snapshots, () {
      final newSnapshotsLength = widget.controller.snapshots.value.length;
      if (newSnapshotsLength > _currentSnapshotsLength) {
        // If new snapshot added, scroll to bottom.
        setState(() => _scrollController.autoScrollToBottom());
      }
      _currentSnapshotsLength = newSnapshotsLength;
    });

    addAutoDisposeListener(widget.controller.selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: widget.controller.snapshots.value.length,
      itemBuilder: (context, index) {
        return Container(
          height: _headerHeight,
          color: widget.controller.selectedIndex.value == index
              ? Theme.of(context).selectedRowColor
              : null,
          child: InkWell(
            canRequestFocus: false,
            onTap: () => widget.controller.selectedIndex.value = index,
            child: _SnapshotListTitle(
              item: widget.controller.snapshots.value[index],
              selected: index == widget.controller.selectedIndex.value,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: smallProgressSize,
      height: smallProgressSize,
      child: CircularProgressIndicator(
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }
}
