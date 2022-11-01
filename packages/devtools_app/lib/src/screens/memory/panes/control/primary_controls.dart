// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../primitives/ui.dart';

class PrimaryControls extends StatelessWidget {
  const PrimaryControls({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChartVisibilityButton(
      showChart: preferences.memory.showChart,
      onPressed: (show) => preferences.memory.showChart.value = show,
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}
