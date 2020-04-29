// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/banner_messages.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import '../../ui/material_icons.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';
import 'memory_heap_tree_view.dart';

class MemoryScreen extends Screen {
  const MemoryScreen() : super(id, title: 'Memory', icon: Octicons.package);

  @visibleForTesting
  static const pauseButtonKey = Key('Pause Button');
  @visibleForTesting
  static const resumeButtonKey = Key('Resume Button');
  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const dropdownIntervalMenuButtonKey =
      Key('Dropdown Interval Menu Button');
  @visibleForTesting
  static const intervalMenuItem = Key('Memory Interval Menu Item');
  @visibleForTesting
  static const intervalKey = Key('Memory Interval');

  @visibleForTesting
  static const dropdownSourceMenuButtonKey = Key('Dropdown Source Menu Button');
  @visibleForTesting
  static const memorySourcesMenuItem = Key('Memory Sources Menu Item');
  @visibleForTesting
  static const memorySourcesKey = Key('Memory Sources');
  @visibleForTesting
  static const exportButtonKey = Key('Export Button');
  @visibleForTesting
  static const resetButtonKey = Key('Reset Button');
  @visibleForTesting
  static const gcButtonKey = Key('GC Button');

  static const memorySourceMenuItemPrefix = 'Source: ';

  static const id = 'memory';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isDartWebAppNow
        ? const MemoryBody()
        : const DisabledForWebAppMessage();
  }
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> with AutoDisposeMixin {
  MemoryChart _memoryChart;

  MemoryController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModeMemoryMessage(context, MemoryScreen.id);

    final newController = Provider.of<MemoryController>(context);
    if (newController == controller) return;
    controller = newController;

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        // TODO(terry): Create the snapshot data to display by Library,
        //              by Class or by Objects.
        // Create the snapshot data by Library.
        controller.createSnapshotByLibrary();
      });
    });

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
            _buildPrimaryStateControls(),
            _buildMemoryControls(),
          ],
        ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            initialFractions: const [0.40, 0.60],
            children: [
              _memoryChart,
              HeapTree(controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intervalDropdown() {
    final files = controller.memoryLog.offlineFiles();

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerboseDropdown = mediaWidth > verboseDropDownMininumWidth;

    final _displayTypes = [
      MemoryController.displayOneMinute,
      MemoryController.displayFiveMinutes,
      MemoryController.displayTenMinutes,
      MemoryController.displayAllMinutes,
    ].map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        return DropdownMenuItem<String>(
          key: MemoryScreen.intervalMenuItem,
          value: value,
          child: Text(
            '${isVerboseDropdown ? 'Display' : ''} $value '
            'Minute${value == MemoryController.displayOneMinute ? '' : 's'}',
            key: MemoryScreen.intervalKey,
          ),
        );
      },
    ).toList();

    return DropdownButton<String>(
      key: MemoryScreen.dropdownIntervalMenuButtonKey,
      value: controller.displayInterval,
      iconSize: 20,
      style: const TextStyle(fontWeight: FontWeight.w100),
      onChanged: (String newValue) {
        setState(
          () {
            controller.displayInterval = newValue;
          },
        );
      },
      items: _displayTypes,
    );
  }

  Widget _memorySourceDropdown() {
    final files = controller.memoryLog.offlineFiles();

    // Can we display dropdowns in verbose mode?
    final isVerbose = controller.memorySourcePrefix ==
        MemoryScreen.memorySourceMenuItemPrefix;

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final allMemorySources = files.map<DropdownMenuItem<String>>((
      String value,
    ) {
      // If narrow width compact the displayed name (remove prefix 'memory_log_').
      final displayValue =
          (!isVerbose && value.startsWith(MemoryController.logFilenamePrefix))
              ? value.substring(MemoryController.logFilenamePrefix.length)
              : value;
      return DropdownMenuItem<String>(
        key: MemoryScreen.memorySourcesMenuItem,
        value: value,
        child: Text(
          '${controller.memorySourcePrefix}$displayValue',
          key: MemoryScreen.memorySourcesKey,
        ),
      );
    }).toList();

    return DropdownButton<String>(
      key: MemoryScreen.dropdownSourceMenuButtonKey,
      value: controller.memorySource,
      iconSize: 20,
      style: const TextStyle(fontWeight: FontWeight.w100),
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

  /// Width of application when primary buttons loose their text.
  static const double _primaryControlsMinVerboseWidth = 1300;

  Widget _buildPrimaryStateControls() {
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
              minIncludeTextWidth: _primaryControlsMinVerboseWidth,
            ),
          ),
          OutlineButton(
            key: MemoryScreen.resumeButtonKey,
            onPressed: controller.paused ? _resumeLiveTimeline : null,
            child: Label(
              playIcon,
              'Resume',
              minIncludeTextWidth: _primaryControlsMinVerboseWidth,
            ),
          ),
          const SizedBox(width: defaultSpacing),
          OutlineButton(
              key: MemoryScreen.clearButtonKey,
              // TODO(terry): Button needs to be Delete for offline data.
              onPressed: controller.memorySource == MemoryController.liveFeed
                  ? _clearTimeline
                  : null,
              child: Label(
                clearIcon,
                'Clear',
                minIncludeTextWidth: _primaryControlsMinVerboseWidth,
              )),
          const SizedBox(width: defaultSpacing),
          _intervalDropdown(),
        ],
      ),
    );
  }

  /// Width of application when memory buttons loose their text.
  static const double _memoryControlsMinVerboseWidth = 1100;

  Widget _buildMemoryControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _memorySourceDropdown(),
          const SizedBox(width: defaultSpacing),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.resetButtonKey,
              onPressed: _reset,
              child: Label(
                memoryReset,
                'Reset',
                minIncludeTextWidth: _memoryControlsMinVerboseWidth,
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
                minIncludeTextWidth: _memoryControlsMinVerboseWidth,
              ),
            ),
          ),
          const SizedBox(width: defaultSpacing),
          Flexible(
            child: OutlineButton(
              key: MemoryScreen.exportButtonKey,
              onPressed:
                  controller.offline ? null : controller.memoryLog.exportMemory,
              child: Label(
                exportIcon,
                'Export',
                minIncludeTextWidth: _memoryControlsMinVerboseWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Callbacks for button actions:

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

  void _reset() async {
    // TODO(terry): TBD real implementation needed.
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
