// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../chart/chart_pane_controller.dart';
import 'primary_controls.dart';
import 'secondary_controls.dart';

class MemoryControlPane extends StatelessWidget {
  const MemoryControlPane({
    Key? key,
    required this.chartController,
  }) : super(key: key);

  final MemoryChartPaneController chartController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PrimaryControls(chartController: chartController),
        const Spacer(),
        SecondaryControls(
          chartController: chartController,
        )
      ],
    );
  }
}
