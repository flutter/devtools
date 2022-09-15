// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../controller/diff_pane_controller.dart';

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
