// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import '../../../../shared/theme.dart';
import 'controller/diff_pane_controller.dart';
import 'controller/item_controller.dart';
import 'widgets/snapshot_control_pane.dart';
import 'widgets/snapshot_list.dart';
import 'widgets/snapshot_view.dart';

class DiffPane extends StatelessWidget {
  const DiffPane({Key? key, required this.controller}) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final Widget itemContent = ValueListenableBuilder<int>(
      valueListenable: controller.selectedIndex,
      builder: (_, index, __) {
        final item = controller.selectedItem;

        if (item is InformationListItem) {
          return const _SnapshotDoc();
        } else if (item is SnapshotListItem) {
          return _SnapshotContent(
            item: item,
            controller: controller,
          );
        } else {
          throw Exception('Unexpected type of item: ${item.runtimeType}.');
        }
      },
    );

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.1, 0.9],
      minSizes: const [80, 80],
      children: [
        OutlineDecoration(
          child: SnapshotList(controller: controller),
        ),
        OutlineDecoration(
          child: itemContent,
        ),
      ],
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
      : assert(controller.selectedItem == item),
        super(key: key);

  final SnapshotListItem item;
  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: denseRowSpacing),
        SnapshotControlPane(controller: controller),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: SnapshotView(controller: controller),
        ),
      ],
    );
  }
}
