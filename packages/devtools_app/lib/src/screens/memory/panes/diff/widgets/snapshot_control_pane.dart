// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/theme.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/model.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.selected as SnapshotListItem;

    return ValueListenableBuilder<bool>(
      valueListenable: controller.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          const SizedBox(width: defaultSpacing),
          if (current.heap != null) ...[
            _DiffDropdown(
              isProcessing: controller.isProcessing,
              current: controller.selected as SnapshotListItem,
              list: controller.snapshots,
            ),
            const SizedBox(width: defaultSpacing),
          ],
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

class _DiffDropdown extends StatelessWidget {
  _DiffDropdown({
    Key? key,
    required this.list,
    required this.current,
    required this.isProcessing,
  }) : super(key: key) {
    final diffWith = current.diffWith.value;
    // Check if diffWith was deleted from list.
    if (diffWith != null &&
        diffWith != current &&
        !list.value.contains(diffWith)) {
      current.diffWith.value = null;
    }
  }

  final ValueListenable<List<DiffListItem>> list;
  final SnapshotListItem current;
  final ValueListenable<bool> isProcessing;

  List<DropdownMenuItem<SnapshotListItem>> items() => list.value
      .where(
        (item) =>
            item is SnapshotListItem &&
            !item.isProcessing.value &&
            item.heap != null,
      )
      .cast<SnapshotListItem>()
      .map(
        (e) => DropdownMenuItem<SnapshotListItem>(
          value: e,
          child: Text(e == current ? '-' : e.name),
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotListItem?>(
      valueListenable: current.diffWith,
      builder: (_, diffWith, __) => Row(
        children: [
          const Text('Diff with:'),
          const SizedBox(width: defaultSpacing),
          RoundedDropDownButton<SnapshotListItem>(
            isDense: true,
            style: Theme.of(context).textTheme.bodyText2,
            value: current.diffWith.value ?? current,
            onChanged: (SnapshotListItem? value) {
              if (value == current) {
                current.diffWith.value = null;
              } else {
                current.diffWith.value = value;
              }
            },
            items: items(),
          ),
        ],
      ),
    );
  }
}
