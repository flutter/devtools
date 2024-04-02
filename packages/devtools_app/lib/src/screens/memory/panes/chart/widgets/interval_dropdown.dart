// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/utils.dart';
import '../../../framework/connected/memory_controller.dart';
import '../controller/chart_pane_controller.dart';
import '../data/primitives.dart';

class IntervalDropdown extends StatefulWidget {
  const IntervalDropdown({Key? key, required this.chartController})
      : super(key: key);

  final MemoryChartPaneController chartController;

  @override
  State<IntervalDropdown> createState() => _IntervalDropdownState();
}

class _IntervalDropdownState extends State<IntervalDropdown>
    with ProvidedControllerMixin<MemoryController, IntervalDropdown> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  Widget build(BuildContext context) {
    final displayTypes =
        ChartInterval.values.map<DropdownMenuItem<ChartInterval>>(
      (
        ChartInterval value,
      ) {
        return DropdownMenuItem<ChartInterval>(
          value: value,
          child: Text(value.displayName),
        );
      },
    ).toList();

    return RoundedDropDownButton<ChartInterval>(
      isDense: true,
      value: widget.chartController.displayInterval,
      onChanged: (ChartInterval? newValue) {
        final value = newValue!;
        setState(() {
          ga.select(
            gac.memory,
            '${gac.MemoryEvent.chartInterval}-${value.displayName}',
          );
          widget.chartController.displayInterval = value;
          final duration = value.duration;

          widget.chartController.event.zoomDuration = duration;
          widget.chartController.vm.zoomDuration = duration;
          widget.chartController.android.zoomDuration = duration;
        });
      },
      items: displayTypes,
    );
  }
}
