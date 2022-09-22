// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/theme.dart';
import '../controller/item_controller.dart';
import '../controller/diff_pane_controller.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isProcessing,
      builder: (_, isProcessing, __) {
        final current = controller.selectedItem as SnapshotListItem;

        return Row(
          children: [
            const SizedBox(width: defaultSpacing),
            if (!isProcessing && current.heap != null) ...[
              _DiffDropdown(
                current: current,
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
        );
      },
    );
  }
}

class _DiffDropdown extends StatelessWidget {
  _DiffDropdown({
    Key? key,
    required this.list,
    required this.current,
  }) : super(key: key) {
    final diffWith = current.diffWith.value;
    // Check if diffWith was deleted from list.
    if (diffWith != null && !list.value.contains(diffWith)) {
      current.setDiffWith(null);
    }
  }

  final ValueListenable<List<DiffListItem>> list;
  final SnapshotListItem current;

  List<DropdownMenuItem<SnapshotListItem>> items() =>
      list.value.where((item) => item.hasData).cast<SnapshotListItem>().map(
        (item) {
          return DropdownMenuItem<SnapshotListItem>(
            value: item,
            child: Text(item == current ? '-' : item.name),
          );
        },
      ).toList();

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
              if ((value ?? current) == current) {
                current.setDiffWith(null);
              } else {
                current.setDiffWith(value);
              }
            },
            items: items(),
          ),
        ],
      ),
    );
  }
}
