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
  const DiffPane({Key? key, required this.diffController}) : super(key: key);

  final DiffPaneController diffController;

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.1, 0.9],
      minSizes: const [80, 80],
      children: [
        OutlineDecoration(
          child: SnapshotList(controller: diffController),
        ),
        OutlineDecoration(
          child: _SnapshotContent(
            controller: diffController,
          ),
        ),
      ],
    );
  }
}

class _SnapshotContent extends StatelessWidget {
  const _SnapshotContent({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotItem>(
      valueListenable: controller.data.derived.selectedItem,
      builder: (_, item, __) {
        if (item is SnapshotDocItem) {
          return const Center(
            child: Text('Snapshot documentation will be here.'),
          );
        }

        return Column(
          children: [
            const SizedBox(height: denseRowSpacing),
            SnapshotControlPane(controller: controller),
            const SizedBox(height: denseRowSpacing),
            Expanded(
              child: SnapshotView(
                controller: controller,
              ),
            ),
          ],
        );
      },
    );
  }
}
