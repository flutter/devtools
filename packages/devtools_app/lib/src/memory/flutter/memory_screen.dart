// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../ui/flutter/label.dart';

import 'memory_chart.dart';
import 'memory_controller.dart';

class MemoryScreen extends Screen {
  const MemoryScreen() : super('Memory');

  @override
  Widget build(BuildContext context) => const MemoryBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Octicons.getIconData('package')),
    );
  }
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  // Creation of the controller must be in the state.
  final MemoryController memoryController = MemoryController();

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
            firstChild: MemoryChart(memoryController),
            secondChild: const Text('Memory Panel TBD'),
            initialFirstFraction: 0.25,
          ),
        ),
      ],
    );
  }

  Widget _leftsideButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlineButton(
          onPressed: memoryController.paused ? null : _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed: memoryController.paused ? _resumeLiveTimeline : null,
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
    memoryController.pauseLiveFeed();
    setState(() {});
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    memoryController.resumeLiveFeed();
    setState(() {});
  }

  void _snapshot() {
    // TODO(terry): Implementation needed.
  }

  void _reset() {
    // TODO(terry): Remove this sample code.
    // Reset the can feed and replay again.
    memoryController.notifyResetFeedListeners();
    _resumeLiveTimeline();
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
