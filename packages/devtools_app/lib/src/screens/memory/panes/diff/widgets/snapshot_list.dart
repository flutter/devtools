// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/primitives/auto_dispose.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/theme.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

final _log = Logger('snapshot_list');

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

@visibleForTesting
const iconToTakeSnapshot = Icons.fiber_manual_record;

class _ListControlPane extends StatelessWidget {
  const _ListControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  Future<void> _takeSnapshot(BuildContext context) async {
    try {
      await controller.takeSnapshot();
    } catch (e, trace) {
      _log.shout(e, e, trace);
      await showDialog(
        context: context,
        builder: (context) => UnexpectedErrorDialog(
          additionalInfo:
              'Encountered an error while taking a heap snapshot:\n$e\n$trace',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isTakingSnapshot,
      builder: (_, isProcessing, __) {
        final clearAllEnabled = !isProcessing && controller.hasSnapshots;
        return Row(
          children: [
            ToolbarAction(
              icon: iconToTakeSnapshot,
              tooltip: 'Take heap snapshot for the selected isolate',
              onPressed: controller.isTakingSnapshot.value
                  ? null
                  : () async => _takeSnapshot(context),
            ),
            ToolbarAction(
              icon: Icons.block,
              tooltip: 'Clear all snapshots',
              onPressed: clearAllEnabled
                  ? () {
                      ga.select(
                        gac.memory,
                        gac.MemoryEvent.diffClearSnapshots,
                      );
                      controller.clearSnapshots();
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotListTitle extends StatelessWidget {
  const _SnapshotListTitle({Key? key, required this.item}) : super(key: key);

  final SnapshotItem item;

  @override
  Widget build(BuildContext context) {
    final theItem = item;
    final theme = Theme.of(context);
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
              ),
            ),
          if (theItem is SnapshotInstanceItem &&
              theItem.memoryFootprint != null) ...[
            Text(
              prettyPrintBytes(
                theItem.memoryFootprint!.reachable,
                includeUnit: true,
                kbFractionDigits: 1,
              )!,
            ),
            const SizedBox(width: denseRowSpacing),
          ],
          if (theItem is SnapshotDocItem)
            Icon(
              Icons.help_outline,
              size: defaultIconSize,
              color: theme.colorScheme.onSurface,
            ),
          if (isProcessing) ...[
            CenteredCircularProgressIndicator(size: smallProgressSize),
            const SizedBox(width: denseRowSpacing),
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
  final _headerHeight = 1.2 * defaultRowHeight;
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
                ? Theme.of(context).colorScheme.selectedRowBackgroundColor
                : null,
            child: InkWell(
              canRequestFocus: false,
              onTap: () => widget.controller.setSnapshotIndex(index),
              child: _SnapshotListTitle(
                item: snapshots[index],
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
