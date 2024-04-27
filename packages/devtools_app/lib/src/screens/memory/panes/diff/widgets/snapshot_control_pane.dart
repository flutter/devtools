// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/memory/simple_items.dart';
import '../../../../../shared/primitives/byte_utils.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/snapshot_item.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({super.key, required this.controller});

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.core.selectedItem as SnapshotDataItem;
    final heapIsReady = current.heap != null;
    if (heapIsReady) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _DiffDropdown(
                current: current,
                controller: controller,
              ),
              const SizedBox(width: defaultSpacing),
              DownloadButton(
                tooltip: 'Download data in CSV format',
                label: 'CSV',
                minScreenWidthForTextBeforeScaling:
                    memoryControlsMinVerboseWidth,
                gaScreen: gac.memory,
                gaSelection: gac.MemoryEvent.diffSnapshotDownloadCsv,
                onPressed: controller.downloadCurrentItemToCsv,
              ),
            ],
          ),
          if (current.heap!.footprint != null)
            Expanded(
              child: _SnapshotSizeView(
                footprint: current.heap!.footprint!,
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _DiffDropdown extends StatelessWidget {
  _DiffDropdown({
    required this.current,
    required this.controller,
  }) {
    final list = controller.core.snapshots.value;
    final diffWith = current.diffWith.value;
    // Check if diffWith was deleted from list.
    if (diffWith != null && !list.contains(diffWith)) {
      current.diffWith.value = null;
    }
  }

  final SnapshotDataItem current;
  final DiffPaneController controller;

  List<DropdownMenuItem<SnapshotDataItem>> items() =>
      controller.core.snapshots.value
          .where((item) => item.hasData)
          .cast<SnapshotDataItem>()
          .map(
        (item) {
          return DropdownMenuItem<SnapshotDataItem>(
            value: item,
            child: Text(item == current ? '-' : item.name),
          );
        },
      ).toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SnapshotDataItem?>(
      valueListenable: current.diffWith,
      builder: (_, diffWith, __) => Row(
        children: [
          const Text('Diff with:'),
          const SizedBox(width: defaultSpacing),
          RoundedDropDownButton<SnapshotDataItem>(
            isDense: true,
            value: current.diffWith.value ?? current,
            onChanged: (SnapshotDataItem? value) {
              late SnapshotDataItem? newDiffWith;
              if ((value ?? current) == current) {
                ga.select(
                  gac.memory,
                  gac.MemoryEvent.diffSnapshotDiffOff,
                );
                newDiffWith = null;
              } else {
                ga.select(
                  gac.memory,
                  gac.MemoryEvent.diffSnapshotDiffSelect,
                );
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

class _SnapshotSizeView extends StatelessWidget {
  const _SnapshotSizeView({required this.footprint});

  final MemoryFootprint footprint;

  @override
  Widget build(BuildContext context) {
    final items = <String, int>{
      'Dart Heap': footprint.dart,
      'Reachable': footprint.reachable,
    };
    return Text(
      items.entries
          .map<String>(
            (e) => '${e.key}: '
                '${prettyPrintBytes(e.value, includeUnit: true, kbFractionDigits: 0)}',
          )
          // TODO(polina-c): consider using vertical divider instead of text.
          .join(' | '),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }
}
