// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../../devtools_app.dart';
import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/memory/simple_items.dart';
import '../../../shared/primitives/simple_elements.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isTakingSnapshot,
      builder: (_, isProcessing, __) {
        final current = controller.core.selectedItem as SnapshotInstanceItem;
        final heapIsReady = !isProcessing && current.heap != null;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (heapIsReady) ...[
                  _DiffDropdown(
                    current: current,
                    controller: controller,
                  ),
                  const SizedBox(width: defaultSpacing),
                  ToCsvButton(
                    minScreenWidthForTextBeforeScaling:
                        memoryControlsMinVerboseWidth,
                    gaScreen: gac.memory,
                    gaSelection: gac.MemoryEvent.diffSnapshotDownloadCsv,
                    onPressed: controller.downloadCurrentItemToCsv,
                  ),
                ],
              ],
            ),
            Row(
              children: [
                if (heapIsReady)
                  _SnapshotSizeView(footprint: current.heap!.footprint),
                _DeleteSnapshotButton(
                  controller: controller,
                  isProcessing: isProcessing,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DeleteSnapshotButton extends StatelessWidget {
  const _DeleteSnapshotButton({
    required this.controller,
    required this.isProcessing,
  });

  final DiffPaneController controller;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return ToolbarAction(
      icon: Icons.clear,
      tooltip: 'Delete snapshot',
      onPressed: isProcessing
          ? null
          : () {
              controller.deleteCurrentSnapshot();
              ga.select(
                gac.memory,
                gac.MemoryEvent.diffSnapshotDelete,
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
  const _SnapshotSizeView({Key? key, required this.footprint})
      : super(key: key);

  final MemoryFootprint footprint;

  @override
  Widget build(BuildContext context) {
    return Text('RSS: ${prettyPrintBytes(footprint.rss, includeUnit: true)} '
        'Dart: ${prettyPrintBytes(footprint.dart, includeUnit: true)} '
        'Reachable: ${prettyPrintBytes(footprint.reachable, includeUnit: true)}');
  }
}
