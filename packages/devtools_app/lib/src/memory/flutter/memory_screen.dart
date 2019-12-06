// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import '../memory_controller.dart';
import 'memory_chart.dart';

class MemoryScreen extends Screen {
  const MemoryScreen();

  @override
  Widget build(BuildContext context) => const MemoryBody();

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Memory',
      icon: Icon(Octicons.package),
    );
  }
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  MemoryChart _memoryChart;

  MemoryController get _controller => Controllers.of(context).memory;

  @override
  void initState() {
    _updateListeningState();

    super.initState();
  }

  @override
  void dispose() {
    // TODO(terry): make my controller disposable via DisposableController and dispose here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _memoryChart = MemoryChart();

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
            firstChild: _memoryChart,
            secondChild: const Text('Memory Panel TBD capacity'),
            initialFirstFraction: 0.25,
          ),
        ),
      ],
    );
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    if (_controller.hasStarted) return;

    await _controller.startTimeline();

    // TODO(terry): Need to set the initial state of buttons.
/*
      pauseButton.disabled = false;
      resumeButton.disabled = true;

      vmMemorySnapshotButton.disabled = false;
      resetAccumulatorsButton.disabled = false;
      gcNowButton.disabled = false;

      memoryChart.disabled = false;
*/
  }

  Widget _leftsideButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlineButton(
          onPressed: _controller.paused ? null : _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed: _controller.paused ? _resumeLiveTimeline : null,
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
    _controller.pauseLiveFeed();
    setState(() {});
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    _controller.resumeLiveFeed();
    setState(() {});
  }

  void _snapshot() {
    // TODO(terry): Implementation needed.
  }

  void _reset() {
    // TODO(terry): TBD real implementation needed.
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
