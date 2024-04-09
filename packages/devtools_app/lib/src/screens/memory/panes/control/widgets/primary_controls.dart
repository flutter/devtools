// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../shared/primitives/simple_elements.dart';

class PrimaryControls extends StatelessWidget {
  const PrimaryControls({
    Key? key,
  }) : super(key: key);

  @visibleForTesting
  static const memoryChartText = 'Memory chart';

  @override
  Widget build(BuildContext context) {
    return VisibilityButton(
      show: preferences.memory.showChart,
      gaScreen: gac.memory,
      onPressed: (show) => preferences.memory.showChart.value = show,
      minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
      label: memoryChartText,
      tooltip: 'Toggle visibility of the Memory usage chart',
    );
  }
}
