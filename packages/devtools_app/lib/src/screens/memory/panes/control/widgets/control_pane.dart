// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../controller/control_pane_controller.dart';
import 'primary_controls.dart';
import 'secondary_controls.dart';

class MemoryControlPane extends StatelessWidget {
  const MemoryControlPane({
    super.key,
    required this.controller,
  });

  final MemoryControlPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PrimaryControls(controller: controller),
        const Spacer(),
        SecondaryControls(controller: controller),
      ],
    );
  }
}
