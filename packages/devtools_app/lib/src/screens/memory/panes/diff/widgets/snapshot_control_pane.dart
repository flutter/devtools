// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/theme.dart';
import '../../../primitives/ui.dart';
import '../../../shared/heap/class_filter.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';
import 'class_filter_dialog.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final filter = controller.core.classFilter;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isTakingSnapshot,
      builder: (_, isProcessing, __) {
        final current = controller.core.selectedItem as SnapshotInstanceItem;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!isProcessing && current.heap != null) ...[
                    _DiffDropdown(
                      current: current,
                      controller: controller,
                    ),
                    const SizedBox(width: defaultSpacing),
                    ValueListenableBuilder<ClassFilter>(
                      valueListenable: filter,
                      builder: (context, filterValue, ___) => FilterButton(
                        onPressed: () => unawaited(
                          showDialog(
                            context: context,
                            builder: (context) => ClassFilterDialog(
                              filterValue,
                              onChanged: controller.applyFilter,
                            ),
                          ),
                        ),
                        isFilterActive: !filter.value.isEmpty,
                        message: filter.value.buttonTooltip,
                      ),
                    ),
                    const SizedBox(width: defaultSpacing),
                    ToCsvButton(
                      minScreenWidthForTextBeforeScaling:
                          primaryControlsMinVerboseWidth,
                      onPressed: controller.downloadCurrentItemToCsv,
                    ),
                  ],
                ],
              ),
              ToolbarAction(
                icon: Icons.clear,
                tooltip: 'Delete snapshot',
                onPressed:
                    isProcessing ? null : controller.deleteCurrentSnapshot,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiffDropdown extends StatelessWidget {
  _DiffDropdown({
    Key? key,
    required this.current,
    required this.controller,
  }) : super(key: key) {
    final list = controller.core.snapshots.value;
    final diffWith = current.diffWith.value;
    // Check if diffWith was deleted from list.
    if (diffWith != null && !list.contains(diffWith)) {
      current.diffWith.value = null;
    }
  }

  final SnapshotInstanceItem current;
  final DiffPaneController controller;

  List<DropdownMenuItem<SnapshotInstanceItem>> items() =>
      controller.core.snapshots.value
          .where((item) => item.hasData)
          .cast<SnapshotInstanceItem>()
          .map(
        (item) {
          return DropdownMenuItem<SnapshotInstanceItem>(
            value: item,
            child: Text(item == current ? '-' : item.name),
          );
        },
      ).toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotInstanceItem?>(
      valueListenable: current.diffWith,
      builder: (_, diffWith, __) => Row(
        children: [
          const Text('Diff with:'),
          const SizedBox(width: defaultSpacing),
          RoundedDropDownButton<SnapshotInstanceItem>(
            isDense: true,
            style: Theme.of(context).textTheme.bodyMedium,
            value: current.diffWith.value ?? current,
            onChanged: (SnapshotInstanceItem? value) {
              late SnapshotInstanceItem? newDiffWith;
              if ((value ?? current) == current) {
                newDiffWith = null;
              } else {
                newDiffWith = value;
              }
              controller.setDiffing(current, newDiffWith);
            },
            items: items(),
          ),
        ],
      ),
    );
  }
}
