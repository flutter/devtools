// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import 'controller/diff_pane_controller.dart';
import 'controller/model.dart';
import 'widgets/snapshot_control_pane.dart';
import 'widgets/snapshot_list.dart';
import 'widgets/snapshot_view.dart';

/// While this pane is under construction, we do not want our users to see it.
///
/// Flip this flag locally to test the pane and flip back before checking in.
/// TODO: before removing this flag add widget/golden testing for the diff pane.
bool shouldShowDiffPane = false;

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key}) : super(key: key);

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

class _DiffPaneState extends State<DiffPane> {
  final controller = DiffPaneController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.selectedIndex,
      builder: (_, index, __) {
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

// class _SnapshotListContent extends StatelessWidget {
//   const _SnapshotListContent({Key? key, required this.item}) : super(key: key);
//   final DiffListItem item;
//
//   @override
//   Widget build(BuildContext context) {
//     final itemLocal = item;
//     if (itemLocal is InformationListItem) {
//       return const Text('Introduction to snapshot diffing will be here.');
//     }
//     if (itemLocal is SnapshotListItem) {
//       return Text('Content of ${itemLocal.name} will be here.');
//     }
//     throw 'Unexpected type of the item: ${itemLocal.runtimeType}';
//   }
// }

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
