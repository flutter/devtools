// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/common_widgets.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/model.dart';

class SnapshotControlPane extends StatelessWidget {
  const SnapshotControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
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
  const _DiffDropdown({
    Key? key,
    required this.list,
    required this.current,
    required this.isProcessing,
  }) : super(key: key);
  final ListValueNotifier<DiffListItem> list;
  final SnapshotListItem current;
  final ValueListenable<bool> isProcessing;

  List<DropdownMenuItem<SnapshotListItem>> items() => list.value
      .where((item) =>
          item is SnapshotListItem &&
          !item.isProcessing.value &&
          !(item.stats == null))
      .cast<SnapshotListItem>()
      .map((e) => DropdownMenuItem<SnapshotListItem>(
            value: e,
            child: Text(e.name),
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Diff with'),
        DropdownButton<SnapshotListItem>(
          value: current,
          icon: const Icon(Icons.arrow_downward),
          //elevation: 16,
          //style: const TextStyle(color: Colors.deepPurple),
          underline: Container(
            height: 2,
            color: Colors.deepPurpleAccent,
          ),
          onChanged: (SnapshotListItem? value) {
            // // This is called when the user selects an item.
            // setState(() {
            //   dropdownValue = value!;
            // });
          },
          items: items(),
        ),
      ],
    );
  }
}
