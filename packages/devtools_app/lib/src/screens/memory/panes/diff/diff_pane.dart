// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import '../../../../shared/table.dart';
import '../../../../shared/theme.dart';
import '../../primitives/memory_utils.dart';
import 'model.dart';

/// While this pane is under construction, we do not want our users to see it.
///
/// Flip this flag locally to test the pane and flip back before checking in.
/// TODO: before removing this flag add widget/golden testing for the diff pane.
bool shouldShowDiffPane = false;

class _DiffPaneController {
  final scrollController = ScrollController();

  /// The list contains one item that show information and all others
  /// are snapshots.
  final snapshots = ListValueNotifier(<DiffListItem>[InformationListItem()]);

  final selectedIndex = ValueNotifier<int>(0);

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  DiffListItem get selected => snapshots.value[selectedIndex.value];

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => snapshots.value.length > 1;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotMemory();
    snapshots.add(
      SnapshotListItem(
        future,
        _nextDisplayNumber(),
        currentIsolateName ?? '<isolate-not-detected>',
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    scrollController.autoScrollToBottom();
    selectedIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    snapshots.removeRange(1, snapshots.value.length);
    selectedIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selected is SnapshotListItem);
    snapshots.removeRange(selectedIndex.value, selectedIndex.value + 1);
    selectedIndex.value = selectedIndex.value - 1;
  }
}

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key}) : super(key: key);

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

class _DiffPaneState extends State<DiffPane> {
  final controller = _DiffPaneController();

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder(
      firstListenable: controller.snapshots,
      secondListenable: controller.selectedIndex,
      builder: (_, snapshots, index, __) {
        return Split(
          axis: Axis.horizontal,
          initialFractions: const [0.2, 0.8],
          minSizes: const [80, 80],
          children: [
            OutlineDecoration(
              child: Column(
                children: [
                  _ListControlPane(controller: controller),
                  Expanded(
                    child: _SnapshotList(controller: controller),
                  ),
                ],
              ),
            ),
            OutlineDecoration(
              child: Column(
                children: [
                  if (controller.selected is SnapshotListItem)
                    _ContentControlPane(controller: controller),
                  Expanded(
                    child: _SnapshotListContent(item: controller.selected),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotList extends StatelessWidget {
  _SnapshotList({Key? key, required this.controller}) : super(key: key);

  final _DiffPaneController controller;
  final headerHeight = 1.20 * defaultRowHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller.scrollController,
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
            const _ProgressIndicator(),
            const SizedBox(width: denseRowSpacing)
          ],
        ],
      ),
    );
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
        color: Theme.of(context).textTheme.bodyText1?.color,
      ),
    );
  }
}

class _SnapshotListContent extends StatelessWidget {
  const _SnapshotListContent({Key? key, required this.item}) : super(key: key);
  final DiffListItem item;

  @override
  Widget build(BuildContext context) {
    final itemLocal = item;
    if (itemLocal is InformationListItem) {
      return const Text('Introduction to snapshot diffing will be here.');
    }
    if (itemLocal is SnapshotListItem) {
      return Text('Content of ${itemLocal.name} will be here.');
    }
    throw 'Unexpected type of the item: ${itemLocal.runtimeType}';
  }
}

class _ListControlPane extends StatelessWidget {
  const _ListControlPane({Key? key, required this.controller})
      : super(key: key);

  final _DiffPaneController controller;

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

class _ContentControlPane extends StatelessWidget {
  const _ContentControlPane({Key? key, required this.controller})
      : super(key: key);

  final _DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          ToolbarAction(
            icon: Icons.clear,
            tooltip: 'Delete snapshot',
            onPressed: isProcessing ? null : controller.deleteCurrentSnapshot,
          ),
        ],
      ),
    );
  }
}
