// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_control.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/widgets/snapshot_list.dart';
import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import '../../../../shared/table.dart';
import '../../../../shared/theme.dart';
import '../../shared/heap/model.dart';
import 'diff_pane_controller.dart';
import 'model.dart';
import 'widgets/snapshot_view.dart';

/// While this pane is under construction, we do not want our users to see it.
///
/// Flip this flag locally to test the pane and flip back before checking in.
/// TODO: before removing this flag add widget/golden testing for the diff pane.
bool shouldShowDiffPane = true;

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key, required this.snapshotTaker}) : super(key: key);
  final SnapshotTaker snapshotTaker;

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

class _DiffPaneState extends State<DiffPane> {
  late DiffPaneController controller;

  @override
  void initState() {
    super.initState();
    controller = DiffPaneController(widget.snapshotTaker);
  }

  @override
  Widget build(BuildContext context) {
    late Widget listContent;
    final item = controller.selected;

    if (item is InformationListItem) {
      listContent = const _SnapshotDoc();
    } else if (item is SnapshotListItem) {
      listContent = _SnapshotContent(
        item: item,
        controller: controller,
      );
    } else {
      throw Exception('Unexpected type of item: ${item.runtimeType}.');
    }

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
              child: SnapshotList(controller: controller),
            ),
            OutlineDecoration(
              child: listContent,
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotDoc extends StatelessWidget {
  const _SnapshotDoc({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('''
        Introduction to snapshot diffing is under construction.
        '''),
    );
  }
}

class _SnapshotContent extends StatelessWidget {
  _SnapshotContent({Key? key, required this.item, required this.controller})
      : assert(controller.selected == item),
        super(key: key);

  final SnapshotListItem item;
  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SnapshotControlPane(controller: controller),
        Expanded(
          child: SnapshotView(item: item),
        ),
      ],
    );
  }
}
