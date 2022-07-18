// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../../devtools_app.dart';
import '../../../../ui/colors.dart';
import '../../primitives/memory_utils.dart';
import 'model.dart';

/// While this pane is under construction, we do not want our users to see it.
///
/// Flip this flag locally to test the pane and flip back before checking in.
/// TODO: before removing this flag add widget/golden testing for the diff pane.
const shouldShowDiffPane = true;

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key}) : super(key: key);

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

/// Will notify if count of items or current index changed.
class _DiffPaneController with ChangeNotifier {
  _DiffPaneController() {
    index.addListener(() => notifyListeners());
  }

  final scrollController = ScrollController();

  /// The list contains one item that show information and all others
  /// are snapshots.
  final snapshots = <DiffListItem>[InformationListItem()];

  final index = ValueNotifier<int>(0);

  /// If true, some process is going on.
  final isProcessing = ValueNotifier<bool>(false);

  DiffListItem get selected => snapshots[index.value];

  bool get hasSnapshots => snapshots.length > 1;

  Future<void> takeSnapshot() async {
    isProcessing.value = true;
    final future = snapshotMemory();
    snapshots.add(
      SnapshotListItem(
        future,
        _nextNameNumber(),
        currentIsolateName ?? '<isolate-not-detected>',
      ),
    );

    notifyListeners();
    await future;
    final newElementIndex = snapshots.length - 1;
    scrollController.autoScrollToBottom();
    index.value = newElementIndex;
    isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    snapshots.removeRange(1, snapshots.length);
    index.value = 0;
    notifyListeners();
  }

  int _nextNameNumber() {
    final numbers = snapshots.map((e) => e.nameNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selected is SnapshotListItem);
    snapshots.removeRange(index.value, index.value + 1);
    index.value = index.value - 1;
  }

  @override
  void dispose() {
    for (var e in snapshots) {
      e.dispose();
    }
    super.dispose();
  }
}

class _DiffPaneState extends State<DiffPane> {
  final controller = _DiffPaneController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Split(
        axis: Axis.horizontal,
        initialFractions: const [0.2, 0.8],
        minSizes: const [80, 80],
        children: [
          Column(
            children: [
              _ListControlPane(controller: controller),
              Expanded(
                child: _SnapshotList(controller: controller),
              ),
            ],
          ),
          Column(
            children: [
              if (controller.selected is SnapshotListItem)
                _ContentControlPane(controller: controller),
              Expanded(
                child: _SnapshotListContent(item: controller.selected),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _SnapshotList extends StatelessWidget {
  const _SnapshotList({Key? key, required this.controller}) : super(key: key);
  final _DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller.scrollController,
      shrinkWrap: true,
      itemCount: controller.snapshots.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: _SnapshotListTitle(
            item: controller.snapshots[index],
            selected: index == controller.index.value,
          ),
          onTap: () => controller.index.value = index,
          key: GlobalObjectKey(controller.snapshots[index]),
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
    return AnimatedBuilder(
      animation: theItem,
      builder: (context, child) => Row(
        children: [
          _SelectionBox(selected: selected),
          const SizedBox(width: denseRowSpacing),
          if (theItem.isProcessing) ...[
            const _ProgressIndicator(),
            const SizedBox(width: denseRowSpacing)
          ],
          if (theItem is SnapshotListItem)
            Expanded(
              child: Text(theItem.name, overflow: TextOverflow.ellipsis),
            ),
          if (theItem is InformationListItem) ...[
            const Text('Snapshots'),
            const SizedBox(width: denseRowSpacing),
            const Icon(Icons.info_outline),
          ]
        ],
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({Key? key}) : super(key: key);
  static const _progressIndicatorSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _progressIndicatorSize,
      height: _progressIndicatorSize,
      child: CircularProgressIndicator(
        color: Theme.of(context).textTheme.bodyText1?.color,
      ),
    );
  }
}

/// Blue or transparent square, to mark selected item.
class _SelectionBox extends StatelessWidget {
  const _SelectionBox({Key? key, required this.selected}) : super(key: key);
  static const _boxSize = Size(3.0, 40.0);
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _boxSize.width,
      height: _boxSize.height,
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: defaultSelectionColor,
              ),
            )
          : null,
    );
  }
}

class _SnapshotListContent extends StatelessWidget {
  const _SnapshotListContent({Key? key, required this.item}) : super(key: key);
  final DiffListItem item;

  @override
  Widget build(BuildContext context) {
    final itemLocal = item;
    if (itemLocal is InformationListItem)
      return const Text('Introduction to snapshot diffing will be here.');
    if (itemLocal is SnapshotListItem)
      return Text('Content of ${itemLocal.name} will be here.');
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
