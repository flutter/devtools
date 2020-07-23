// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../octicons.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/label.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';
import 'memory_events_pane.dart';
import 'memory_heap_tree_view.dart';

/// Width of application when memory buttons loose their text.
const _primaryControlsMinVerboseWidth = 1100.0;

class MemoryScreen extends Screen {
  const MemoryScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'Memory',
          icon: Octicons.package,
        );

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
  static const gcButtonKey = Key('GC Button');

  static const memorySourceMenuItemPrefix = 'Source: ';

  static const id = 'memory';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const MemoryBody();
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> with AutoDisposeMixin {
  @visibleForTesting
  static const androidChartButtonKey = Key('Android Chart');

  MemoryChart _memoryChart;
  MemoryEventsPane _memoryEvents;

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
    final textTheme = Theme.of(context).textTheme;

    controller.memorySourcePrefix = mediaWidth > verboseDropDownMininumWidth
        ? MemoryScreen.memorySourceMenuItemPrefix
        : '';

    _memoryEvents ??= MemoryEventsPane();
    _memoryChart = MemoryChart();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPrimaryStateControls(textTheme),
            const Expanded(child: SizedBox(width: denseSpacing)),
            _buildMemoryControls(textTheme),
          ],
        ),
        SizedBox(
          height: 50,
          child: _memoryEvents,
        ),
        SizedBox(
          child: _memoryChart,
        ),
        const PaddedDivider(padding: EdgeInsets.zero),
        Expanded(
          child: HeapTree(controller),
        ),
      ],
    );
  }

  Widget _intervalDropdown(TextTheme textTheme) {
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

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: MemoryScreen.dropdownIntervalMenuButtonKey,
        style: textTheme.bodyText2,
        value: controller.displayInterval,
        onChanged: (String newValue) {
          setState(() {
            controller.displayInterval = newValue;
          });
        },
        items: _displayTypes,
      ),
    );
  }

  Widget _memorySourceDropdown(TextTheme textTheme) {
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

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: MemoryScreen.dropdownSourceMenuButtonKey,
        style: textTheme.bodyText2,
        value: controller.memorySource,
        onChanged: (String newValue) {
          setState(() {
            controller.memorySource = newValue;
          });
        },
        items: allMemorySources,
      ),
    );
  }

  void _updateListeningState() async {
    await serviceManager.onServiceAvailable;

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

  Widget _buildPrimaryStateControls(TextTheme textTheme) {
    return ValueListenableBuilder(
      valueListenable: controller.paused,
      builder: (context, paused, _) {
        return Row(
          children: [
            OutlineButton(
              key: MemoryScreen.pauseButtonKey,
              onPressed: paused ? null : controller.pauseLiveFeed,
              child: const MaterialIconLabel(
                Icons.pause,
                'Pause',
                includeTextWidth: _primaryControlsMinVerboseWidth,
              ),
            ),
            const SizedBox(width: denseSpacing),
            OutlineButton(
              key: MemoryScreen.resumeButtonKey,
              onPressed: paused ? controller.resumeLiveFeed : null,
              child: const MaterialIconLabel(
                Icons.play_arrow,
                'Resume',
                includeTextWidth: _primaryControlsMinVerboseWidth,
              ),
            ),
            const SizedBox(width: defaultSpacing),
            OutlineButton(
                key: MemoryScreen.clearButtonKey,
                // TODO(terry): Button needs to be Delete for offline data.
                onPressed: controller.memorySource == MemoryController.liveFeed
                    ? _clearTimeline
                    : null,
                child: const MaterialIconLabel(
                  Icons.block,
                  'Clear',
                  includeTextWidth: _primaryControlsMinVerboseWidth,
                )),
            const SizedBox(width: defaultSpacing),
            _intervalDropdown(textTheme),
          ],
        );
      },
    );
  }

  OutlineButton createToggleAdbMemoryButton() {
    return OutlineButton(
      key: androidChartButtonKey,
      onPressed: controller.isConnectedDeviceAndroid
          ? _toggleAndroidChartVisibility
          : null,
      child: MaterialIconLabel(
        controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
        'Android Memory',
        includeTextWidth: 900,
      ),
    );
  }

  void _toggleAndroidChartVisibility() {
    setState(() {
      controller.toggleAndroidChartVisibility();
    });
  }

  Widget _buildMemoryControls(TextTheme textTheme) {
    return Row(
      children: [
        _memorySourceDropdown(textTheme),
        const SizedBox(width: defaultSpacing),
        createToggleAdbMemoryButton(),
        const SizedBox(width: denseSpacing),
        OutlineButton(
          key: MemoryScreen.gcButtonKey,
          onPressed: controller.isGcing ? null : _gc,
          child: const MaterialIconLabel(
            Icons.delete,
            'GC',
            includeTextWidth: _primaryControlsMinVerboseWidth,
          ),
        ),
        const SizedBox(width: defaultSpacing),
        OutlineButton(
          key: MemoryScreen.exportButtonKey,
          onPressed:
              controller.offline ? null : controller.memoryLog.exportMemory,
          child: const MaterialIconLabel(
            Icons.file_download,
            'Export',
            includeTextWidth: _primaryControlsMinVerboseWidth,
          ),
        ),
      ],
    );
  }

  /// Callbacks for button actions:

  void _clearTimeline() {
    controller.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    controller.monitorAllocations = [];

    // Clear all analysis and snapshots collected too.
    controller.clearAllSnapshots();
    controller.classRoot = null;
    controller.topNode = null;
    controller.selectedSnapshotTimestamp = null;
  }

  Future<void> _gc() async {
    // TODO(terry): Record GC in analytics.
    try {
      log('User Initiated GC Start');

      // TODO(terry): Only record GCs not when user initiated.
      controller.memoryTimeline.addGCEvent();

      await controller.gc();

      log('User GC Complete');
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }
}
