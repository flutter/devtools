// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import 'model.dart';

/// Wile this pane is under construction, we do not want our users to see it.
/// Flip this flag locally to test the pane and flip back before checking in.
const shouldShowDiffPane = true;

class DiffPane extends StatefulWidget {
  const DiffPane({Key? key}) : super(key: key);

  @override
  State<DiffPane> createState() => _DiffPaneState();
}

class _DiffPaneController {
  final snapshots = <Snapshot>[];
}

class _DiffPaneState extends State<DiffPane> {
  @override
  Widget build(BuildContext context) {
    return const Text('hello, I am diff pane');
  }
}

class _ControlPane extends StatelessWidget {
  const _ControlPane({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ToolbarAction(
          icon: Icons.fiber_manual_record,
          tooltip: 'Take heap snapshot',
          onPressed: () {},
        ),
        ToolbarAction(
          icon: Icons.block,
          tooltip: 'Clear all snapshots',
          onPressed: () {},
        )
      ],
    );
  }
}
