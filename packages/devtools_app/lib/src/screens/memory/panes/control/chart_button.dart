// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../primitives/ui.dart';

class ChartButton extends StatelessWidget {
  const ChartButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: preferences.memory.showChart,
      builder: (_, showChart, __) => IconLabelButton(
        key: key,
        tooltip: showChart ? 'Hide chart' : 'Show chart',
        icon: showChart ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        label: 'Chart',
        minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        onPressed: () => preferences.memory.showChart.value =
            !preferences.memory.showChart.value,
      ),
    );
  }
}
