// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import '../chart/chart_pane_controller.dart';
import 'constants.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerboseDropdown = mediaWidth > verboseDropDownMinimumWidth;

    final displayOneMinute =
        chartDuration(ChartInterval.OneMinute)!.inMinutes.toString();

    final _displayTypes = displayDurationsStrings.map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        final unit = value == displayDefault || value == displayAll
            ? ''
            : 'Minute${value == displayOneMinute ? '' : 's'}';

        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            '${isVerboseDropdown ? 'Display' : ''} $value $unit',
          ),
        );
      },
    ).toList();

    return RoundedDropDownButton<String>(
      isDense: true,
      style: textTheme.bodyText2,
      value: displayDuration(controller.displayInterval),
      onChanged: (String? newValue) {
        setState(() {
          ga.select(
            analytics_constants.memory,
            '${analytics_constants.memoryDisplayInterval}-$newValue',
          );
          controller.displayInterval = chartInterval(newValue!);
          final duration = chartDuration(controller.displayInterval);

          widget.chartController.event.zoomDuration = duration;
          widget.chartController.vm.zoomDuration = duration;
          widget.chartController.android.zoomDuration = duration;
        });
      },
      items: _displayTypes,
    );
  }
}
