// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/globals.dart';
import '../../../../../shared/ui/common_widgets.dart';
import '../../../shared/primitives/simple_elements.dart';

class PrimaryControls extends StatelessWidget {
  const PrimaryControls({super.key});

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
