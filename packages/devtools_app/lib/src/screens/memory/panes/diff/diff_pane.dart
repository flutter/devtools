// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import 'model.dart';

/// While this pane is under construction, we do not want our users to see it.
/// Flip this flag locally to test the pane and flip back before checking in.
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

  final snapshots = <SnapshotListItem>[
    SnapshotInformation(),
    SnapshotInformation()
  ];
  final index = ValueNotifier<int>(0);
  SnapshotListItem get selected => snapshots[index.value];
}

class _DiffPaneState extends State<DiffPane> {
  final controller = _DiffPaneController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.2, 0.8],
      minSizes: const [80, 80],
      children: [
        Column(
          children: [
            _ControlPane(controller: controller),
            Expanded(
              child: _SnapshotList(controller: controller),
            ),
          ],
        ),
        _SnapshotListContent(item: controller.selected),
      ],
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
      shrinkWrap: true,
      itemCount: controller.snapshots.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: _SnapshotListTitle(
            item: controller.snapshots[index],
            selected: index == controller.index.value,
          ),
          onTap: () => controller.index.value = index,
        );
      },
    );
  }
}

const _itemHeight = 28.0;

class _SnapshotListTitle extends StatelessWidget {
  const _SnapshotListTitle(
      {Key? key, required this.item, required this.selected})
      : super(key: key);
  final SnapshotListItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final itemLocal = item;

    return Row(
      children: [
        SizedBox(
          width: 10,
          height: _itemHeight,
          child: selected
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.red),
                )
              : null,
        ),
        if (itemLocal is SnapshotInformation) const Text('Snapshots'),
        if (itemLocal is Snapshot) Text(itemLocal.name),
      ],
    );
  }
}

class _SnapshotListContent extends StatelessWidget {
  const _SnapshotListContent({Key? key, required this.item}) : super(key: key);
  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    final itemLocal = item;
    if (itemLocal is SnapshotInformation)
      return const Text('Information about snapshots');
    if (itemLocal is Snapshot) return Text('Content of ${itemLocal.name}.');
    throw 'Unexpected type of the item: ${itemLocal.runtimeType}';
  }
}

class _ControlPane extends StatelessWidget {
  const _ControlPane({Key? key, required this.controller}) : super(key: key);

  final _DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ToolbarAction(
          icon: Icons.fiber_manual_record,
          tooltip: 'Take heap snapshot',
          onPressed: () {},
        ),
        ToolbarAction(
          icon: Icons.block,
          tooltip: 'Clear all snapshots',
          onPressed: () {},
        )
      ],
    );
  }
}
