// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/primitives/auto_dispose.dart';
import '../../../../../shared/primitives/utils.dart';
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
        OutlineDecoration.onlyBottom(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: denseSpacing,
              horizontal: densePadding,
            ),
            child: _ListControlPane(controller: controller),
          ),
        ),
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
      valueListenable: controller.isTakingSnapshot,
      builder: (_, isProcessing, __) {
        final clearAllEnabled = !isProcessing && controller.hasSnapshots;
        return Row(
          children: [
            ToolbarAction(
              icon: Icons.fiber_manual_record,
              tooltip: 'Take heap snapshot for the selected isolate',
              onPressed: controller.takeSnapshotHandler(
                gac.MemoryEvent.diffTakeSnapshotControlPane,
              ),
            ),
            ToolbarAction(
              icon: Icons.block,
              tooltip: 'Clear all snapshots',
              onPressed: clearAllEnabled
                  ? () async {
                      ga.select(
                        gac.memory,
                        gac.MemoryEvent.diffClearSnapshots,
                      );
                      unawaited(controller.clearSnapshots());
                    }
                  : null,
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
    final theme = Theme.of(context);
    final textStyle =
        selected ? theme.selectedTextStyle : theme.regularTextStyle;

    return ValueListenableBuilder<bool>(
      valueListenable: theItem.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          const SizedBox(width: denseRowSpacing),
          if (theItem is SnapshotInstanceItem)
            Expanded(
              child: Text(
                theItem.name,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          if (theItem is SnapshotInstanceItem && theItem.totalSize != null) ...[
            Text(
              prettyPrintBytes(
                theItem.totalSize,
                includeUnit: true,
                kbFractionDigits: 1,
              )!,
              style: textStyle,
            ),
            const SizedBox(width: denseRowSpacing)
          ],
          if (theItem is SnapshotDocItem)
            Expanded(
              child: Text(
                'Snapshots',
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          if (isProcessing) ...[
            CenteredCircularProgressIndicator(size: smallProgressSize),
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
          final selected = selectedIndex == index;
          return Container(
            height: _headerHeight,
            color: selected
                ? Theme.of(context).colorScheme.selectedRowColor
                : null,
            child: InkWell(
              canRequestFocus: false,
              onTap: () => widget.controller.setSnapshotIndex(index),
              child: _SnapshotListTitle(
                item: snapshots[index],
                selected: selected,
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
