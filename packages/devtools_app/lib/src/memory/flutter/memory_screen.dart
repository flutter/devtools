// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../ui/flutter/label.dart';

import 'memory_chart.dart';
import 'memory_controller.dart';

class MemoryScreen extends Screen {
  const MemoryScreen() : super('Memory');

  @override
  Widget build(BuildContext context) => MemoryBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Octicons.getIconData('package')),
    );
  }
}

class MemoryBody extends StatefulWidget {
  MemoryBody();

  final MemoryController memoryController = MemoryController();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _leftsideButtons(),
            _rightsideButtons(),
          ],
        ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            firstChild: MemoryChart(widget.memoryController),
            secondChild: const Text('Memory Panel TBD'),
            initialFirstFraction: 0.25,
            // TODO(terry): Eliminate hack - fix resizing of chart canvas during Build phase.
            callback: _updateChart,
          ),
        ),
      ],
    );
  }

  // TODO(terry): Eliminate hack need to recompute size of chart canvas during Build.
  void _updateChart() {
    // Update the chart using its new size.
    SchedulerBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  Widget _leftsideButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlineButton(
          onPressed: widget.memoryController.paused ? null : _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed:
              widget.memoryController.paused ? _resumeLiveTimeline : null,
          child: const MaterialIconLabel(
            Icons.play_arrow,
            'Resume',
            minIncludeTextWidth: 900,
          ),
        ),
      ],
    );
  }

  Widget _rightsideButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlineButton(
          onPressed: _snapshot,
          child: MaterialIconLabel(
            Icons.camera,
            'Snapshot',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          onPressed: _reset,
          child: MaterialIconLabel(
            Icons.settings_backup_restore,
            'Reset',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          onPressed: _gc,
          child: MaterialIconLabel(
            Icons.delete_sweep,
            'GC',
            minIncludeTextWidth: 1100,
          ),
        ),
      ],
    );
  }

  // Callbacks for button actions:

  void _pauseLiveTimeline() {
    // TODO(terry): Implement real pause when connected to live feed.
    widget.memoryController.pauseTimer();
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    widget.memoryController.resumeTimer();
  }

  void _snapshot() {
    // TODO(terry): Implementation needed.
  }

  void _reset() {
    // TODO(terry): Implementation needed.
    setState(() {});
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
