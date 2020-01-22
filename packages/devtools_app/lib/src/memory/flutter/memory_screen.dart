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
import '../../ui/material_icons.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';

class MemoryScreen extends Screen {
  const MemoryScreen();

  @visibleForTesting
  static const pauseButtonKey = Key('Pause Button');
  @visibleForTesting
  static const resumeButtonKey = Key('Resume Button');
  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const dropdownPruneMenuButtonKey = Key('Dropdown Prune Menu Button');
  @visibleForTesting
  static const pruneMenuItem = Key('Memory Prune Menu Item');
  @visibleForTesting
  static const pruneIntervalKey = Key('Memory Prune Interval');

  @visibleForTesting
  static const dropdownSourceMenuButtonKey = Key('Dropdown Source Menu Button');
  @visibleForTesting
  static const memorySourcesMenuItem = Key('Memory Sources Menu Item');
  @visibleForTesting
  static const memorySourcesKey = Key('Memory Sources');
  @visibleForTesting
  static const exportButtonKey = Key('Export Button');
  @visibleForTesting
  static const snapshotButtonKey = Key('Snapshot Button');
  @visibleForTesting
  static const resetButtonKey = Key('Reset Button');
  @visibleForTesting
  static const gcButtonKey = Key('GC Button');

  static const memorySourceMenuItemPrefix = 'Source: ';

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

  MemoryController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Controllers.of(context).memory;
    if (newController == controller) return;
    controller = newController;

    _updateListeningState();
  }

  /// When to have verbose Dropdown based on media width.
  static const verboseDropDownMininumWidth = 950;

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    controller.memorySourcePrefix = mediaWidth > verboseDropDownMininumWidth
        ? MemoryScreen.memorySourceMenuItemPrefix
        : '';

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

  Widget _pruneDropdown() {
    final files = controller.memoryLog.offlineFiles();

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerbaseDropdown = mediaWidth > verboseDropDownMininumWidth;

    final _displayTypes = [
      MemoryController.displayOneMinute,
      MemoryController.displayFiveMinutes,
      MemoryController.displayTenMinutes,
      MemoryController.displayAllMinutes,
    ].map<DropdownMenuItem<String>>((
      String value,
    ) {
      return DropdownMenuItem<String>(
        key: MemoryScreen.pruneMenuItem,
        value: value,
        child: Text(
          '${isVerbaseDropdown ? 'Display' : ''} $value '
          'Minute${value == MemoryController.displayOneMinute ? '' : 's'}',
          key: MemoryScreen.pruneIntervalKey,
        ),
      );
    }).toList();

    return DropdownButton<String>(
      key: MemoryScreen.dropdownPruneMenuButtonKey,
      value: controller.pruneInterval,
      iconSize: 20,
      style: TextStyle(fontWeight: FontWeight.w100),
      onChanged: (String newValue) {
        setState(() {
          controller.pruneInterval = newValue;
        });
      },
      items: _displayTypes,
    );
  }

  Widget _memorySourceDropdown() {
    final files = controller.memoryLog.offlineFiles();

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final allMemorySources = files.map<DropdownMenuItem<String>>((
      String value,
    ) {
      return DropdownMenuItem<String>(
        key: MemoryScreen.memorySourcesMenuItem,
        value: value,
        child: Text(
          '${controller.memorySourcePrefix}$value',
          key: MemoryScreen.memorySourcesKey,
        ),
      );
    }).toList();

    return DropdownButton<String>(
      key: MemoryScreen.dropdownSourceMenuButtonKey,
      value: controller.memorySource,
      iconSize: 20,
      style: TextStyle(fontWeight: FontWeight.w100),
      onChanged: (String newValue) {
        setState(() {
          controller.memorySource = newValue;
        });
      },
      items: allMemorySources,
    );
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    if (controller != null && controller.hasStarted) return;

    if (controller != null) await controller.startTimeline();

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

  static const minIncludeTextLeftButtons = 1300;
  static const minIncludeTextRightButtons = 1100;

  Widget _leftsideButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      // Add a semi-transparent background to the
      // expand and collapse buttons so they don't interfere
      // too badly with the tree content when the tree
      // is narrow.
      color: Theme.of(context).scaffoldBackgroundColor.withAlpha(200),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlineButton(
            key: MemoryScreen.pauseButtonKey,
            onPressed: controller.paused ? null : _pauseLiveTimeline,
            child: Label(
              pauseIcon,
              'Pause',
              minIncludeTextWidth: 1300,
            ),
          ),
          OutlineButton(
            key: MemoryScreen.resumeButtonKey,
            onPressed: controller.paused ? _resumeLiveTimeline : null,
            child: Label(
              playIcon,
              'Resume',
              minIncludeTextWidth: 1300,
            ),
          ),
          const SizedBox(width: 16.0),
          OutlineButton(
              key: MemoryScreen.clearButtonKey,
              onPressed: controller.memorySource == MemoryController.liveFeed
                  ? _clearTimeline
                  : null,
              child: Label(
                clearIcon,
                'Clear',
                minIncludeTextWidth: 1300,
              )),
          const SizedBox(width: 16.0),
          _pruneDropdown(),
        ],
      ),
    );
  }

  Widget _rightsideButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      // Add a semi-transparent background to the
      // expand and collapse buttons so they don't interfere
      // too badly with the tree content when the tree
      // is narrow.
      color: Theme.of(context).scaffoldBackgroundColor.withAlpha(200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _memorySourceDropdown(),
          const SizedBox(width: 16.0),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.snapshotButtonKey,
              onPressed: _snapshot,
              child: Label(
                memorySnapshot,
                'Snapshot',
                minIncludeTextWidth: 1100,
              ),
            ),
          ),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.resetButtonKey,
              onPressed: _reset,
              child: Label(
                memoryReset,
                'Reset',
                minIncludeTextWidth: 1100,
              ),
            ),
          ),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.gcButtonKey,
              onPressed: _gc,
              child: Label(
                memoryGC,
                'GC',
                minIncludeTextWidth: 1100,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.exportButtonKey,
              onPressed:
                  controller.offline ? null : controller.memoryLog.exportMemory,
              child: Label(
                exportIcon,
                'Export',
                minIncludeTextWidth: 1100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Callbacks for button actions:

  void _clearTimeline() {
    controller.memoryTimeline.reset();
  }

  void _pauseLiveTimeline() {
    // TODO(terry): Implement real pause when connected to live feed.
    controller.pauseLiveFeed();
    setState(() {});
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    controller.resumeLiveFeed();
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
