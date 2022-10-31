// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../memory_controller.dart';
import '../../primitives/ui.dart';
import '../chart/chart_pane_controller.dart';

class PrimaryControls extends StatelessWidget {
  const PrimaryControls({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChartVisibilityButton(
          showChart: preferences.memory.showChart,
          onPressed: (show) => preferences.memory.showChart.value = show,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
      ],
    );
  }
}
