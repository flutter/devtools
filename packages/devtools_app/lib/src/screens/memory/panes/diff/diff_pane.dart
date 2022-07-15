// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../devtools_app.dart';
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
        SelectionBox(selected: selected),
        const SizedBox(width: denseRowSpacing),
        Expanded(child: Text(itemLocal.name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class SelectionBox extends StatelessWidget {
  static const _selectionSize = const Size(4.0, 40.0);
  const SelectionBox({Key? key, required this.selected}) : super(key: key);
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _selectionSize.width,
      height: _selectionSize.height,
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                // TODO: get proper blue from theme somewhere.
                color: Colors.blue,
              ),
            )
          : null,
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
