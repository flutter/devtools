// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../octicons.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/label.dart';
import '../utils.dart';
import 'memory_android_chart.dart';
import 'memory_controller.dart';
import 'memory_events_pane.dart';
import 'memory_heap_tree_view.dart';
import 'memory_heap_treemap.dart';
import 'memory_vm_chart.dart';

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

  static const legendKeyName = 'Legend Button';

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
  @visibleForTesting
  static const legendButtonkey = Key(legendKeyName);

  static const memorySourceMenuItemPrefix = 'Source: ';

  static const id = 'memory';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const MemoryBody();
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  static const List<Tab> memoryTabs = [
    Tab(text: 'Dart Heap'),
    Tab(text: 'Heap Treemap'),
  ];

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  @visibleForTesting
  static const androidChartButtonKey = Key('Android Chart');

  EventChartController eventChartController;
  VMChartController vmChartController;
  AndroidChartController androidChartController;

  MemoryController controller;
  TabController tabController;

  OverlayEntry legendOverlayEntry;

  @override
  void initState() {
    super.initState();

    ga.screen(MemoryScreen.id);

    tabController = TabController(
      length: MemoryBody.memoryTabs.length,
      vsync: this,
    );
    addAutoDisposeListener(tabController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModeMemoryMessage(context, MemoryScreen.id);

    final newController = Provider.of<MemoryController>(context);
    if (newController == controller) return;

    controller = newController;

    eventChartController = EventChartController(controller);
    vmChartController = VMChartController(controller);
    // Android Chart uses the VM Chart's computed labels.
    androidChartController = AndroidChartController(
      controller,
      sharedLabels: vmChartController.labelTimestamps,
    );

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        // TODO(terry): Create the snapshot data to display by Library,
        //              by Class or by Objects.
        // Create the snapshot data by Library.
        controller.createSnapshotByLibrary();
      });
    });

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.memorySourceNotifier, () {
      setState(() {
        controller.updatedMemorySource();
        _refreshCharts();
      });
    });

    addAutoDisposeListener(controller.legendVisibleNotifier, () {
      setState(() {
        controller.isLegendVisible ? showLegend(context) : hideLegend();
      });
    });

    addAutoDisposeListener(controller.androidChartVisibleNotifier, () {
      setState(() {
        if (controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          hideLegend();
          showLegend(context);
        }
      });
    });

    _updateListeningState();
  }

  /// When to have verbose Dropdown based on media width.
  static const verboseDropDownMinimumWidth = 950;

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;

    controller.memorySourcePrefix = mediaWidth > verboseDropDownMinimumWidth
        ? MemoryScreen.memorySourceMenuItemPrefix
        : '';
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
          child: MemoryEventsPane(eventChartController),
        ),
        SizedBox(
          child: MemoryVMChart(vmChartController),
        ),
        controller.isAndroidChartVisible
            ? SizedBox(
                height: defaultChartHeight,
                child: MemoryAndroidChart(androidChartController),
              )
            : const SizedBox(),
        const SizedBox(height: defaultSpacing),
        Row(
          children: [
            TabBar(
              labelColor: textTheme.bodyText1.color,
              isScrollable: true,
              controller: tabController,
              tabs: MemoryBody.memoryTabs,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(width: defaultSpacing),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: tabController,
            children: [
              HeapTree(controller),
              MemoryHeapTreemap(controller),
            ],
          ),
        ),
      ],
    );
  }

  void _refreshCharts() {
    // Remove history of all plotted data in all charts.
    eventChartController?.reset();
    vmChartController?.reset();
    androidChartController?.reset();

    _recomputeChartData();
  }

  /// Recompute (attach data to the chart) for either live or offline data source.
  void _recomputeChartData() {
    eventChartController.setupData();
    eventChartController.dirty = true;
    vmChartController.setupData();
    vmChartController.dirty = true;
    androidChartController.setupData();
    androidChartController.dirty = true;
  }

  Widget _intervalDropdown(TextTheme textTheme) {
    final files = controller.memoryLog.offlineFiles();

    // First item is 'Live Feed', then followed by memory log filenames.
    files.insert(0, MemoryController.liveFeed);

    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerboseDropdown = mediaWidth > verboseDropDownMinimumWidth;

    final displayOneMinute =
        chartDuration(ChartInterval.OneMinute).inMinutes.toString();

    final _displayTypes = displayDurationsStrings.map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        final unit = value == displayDefault || value == displayAll
            ? ''
            : 'Minute${value == displayOneMinute ? '' : 's'}';

        return DropdownMenuItem<String>(
          key: MemoryScreen.intervalMenuItem,
          value: value,
          child: Text(
            '${isVerboseDropdown ? 'Display' : ''} $value $unit',
            key: MemoryScreen.intervalKey,
          ),
        );
      },
    ).toList();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: MemoryScreen.dropdownIntervalMenuButtonKey,
        style: textTheme.bodyText2,
        value: displayDuration(controller.displayInterval),
        onChanged: (String newValue) {
          setState(() {
            controller.displayInterval = chartInterval(newValue);
            final duration = chartDuration(controller.displayInterval);

            eventChartController?.zoomDuration = duration;
            vmChartController?.zoomDuration = duration;
            androidChartController?.zoomDuration = duration;
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
            PauseButton(
              key: MemoryScreen.pauseButtonKey,
              includeTextWidth: _primaryControlsMinVerboseWidth,
              onPressed: paused ? null : controller.pauseLiveFeed,
            ),
            const SizedBox(width: denseSpacing),
            ResumeButton(
              key: MemoryScreen.resumeButtonKey,
              includeTextWidth: _primaryControlsMinVerboseWidth,
              onPressed: paused ? controller.resumeLiveFeed : null,
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
          ? controller.toggleAndroidChartVisibility
          : null,
      child: MaterialIconLabel(
        controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
        'Android Memory',
        includeTextWidth: 900,
      ),
    );
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
        const SizedBox(width: defaultSpacing),
        OutlineButton(
          key: legendKey,
          onPressed: controller.toggleLegendVisibility,
          child: MaterialIconLabel(
            legendOverlayEntry == null ? Icons.storage : Icons.close,
            'Legend',
            includeTextWidth: _primaryControlsMinVerboseWidth,
          ),
        ),
      ],
    );
  }

  final legendKey = GlobalKey(debugLabel: MemoryScreen.legendKeyName);
  static const legendXOffset = 20;
  static const legendYOffset = 7.0;
  static const legendWidth = 200.0;
  static const legendTextWidth = 55.0;
  static const legendHeight1Chart = 185.0;
  static const legendHeight2Charts = 340.0;

  // TODO(terry): Consider custom painter?
  static const base = 'assets/img/legend/';
  static const snapshotManualLegend = '${base}snapshot_manual_glyph.png';
  static const snapshotAutoLegend = '${base}snapshot_auto_glyph.png';
  static const monitorLegend = '${base}monitor_glyph.png';
  static const resetLegend = '${base}reset_glyph.png';
  static const gcManualLegend = '${base}gc_manual_glyph.png';
  static const gcVMLegend = '${base}gc_vm_glyph.png';
  static const capacityLegend = '${base}capacity_glyph.png';
  static const usedLegend = '${base}used_glyph.png';
  static const externalLegend = '${base}external_glyph.png';
  static const rssLegend = '${base}rss_glyph.png';
  static const androidTotalLegend = '${base}android_total_glyph.png';
  static const androidOtherLegend = '${base}android_other_glyph.png';
  static const androidCodeLegend = '${base}android_code_glyph.png';
  static const androidNativeLegend = '${base}android_native_glyph.png';
  static const androidJavaLegend = '${base}android_java_glyph.png';
  static const androidStackLegend = '${base}android_stack_glyph.png';
  static const androidGraphicsLegend = '${base}android_graphics_glyph.png';

  Widget legendRow({String name1, String image1, String name2, String image2}) {
    final legendEntry = Theme.of(context).textTheme.caption;

    List<Widget> legendPart(
      String name,
      String image, [
      double leftEdge = 5.0,
    ]) {
      final rightSide = <Widget>[];
      if (name != null && image != null) {
        rightSide.addAll([
          Container(
            padding: EdgeInsets.fromLTRB(leftEdge, 0, 0, 2),
            width: legendTextWidth + leftEdge,
            child: Text(name, style: legendEntry),
          ),
          const PaddedDivider(
            padding: EdgeInsets.only(left: denseRowSpacing),
          ),
          Image(image: AssetImage(image)),
        ]);
      }

      return rightSide;
    }

    final rowChildren = <Widget>[];
    rowChildren.addAll(legendPart(name1, image1));
    if (name2 != null && image2 != null) {
      rowChildren.addAll(legendPart(name2, image2, 20.0));
    }

    return Container(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 2),
        child: Row(
          children: rowChildren,
        ));
  }

  void showLegend(BuildContext context) {
    final RenderBox box = legendKey.currentContext.findRenderObject();

    // Global position.
    final position = box.localToGlobal(Offset.zero);

    final legendHeading = Theme.of(context).textTheme.subtitle2;
    final OverlayState overlayState = Overlay.of(context);
    legendOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + box.size.height + legendYOffset,
        left: position.dx - legendWidth + box.size.width - legendXOffset,
        height: controller.isAndroidChartVisible
            ? legendHeight2Charts
            : legendHeight1Chart,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 5, 0, 8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.yellow),
            borderRadius: BorderRadius.circular(10.0),
          ),
          width: legendWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 0, 4),
                child: Text('Events Legend', style: legendHeading),
              ),
              legendRow(
                name1: 'Snapshot',
                image1: snapshotManualLegend,
                name2: 'Auto',
                image2: snapshotAutoLegend,
              ),
              legendRow(
                name1: 'Monitor',
                image1: monitorLegend,
                name2: 'Reset',
                image2: resetLegend,
              ),
              legendRow(
                name1: 'GC VM',
                image1: gcVMLegend,
                name2: 'Manual',
                image2: gcManualLegend,
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 0, 4),
                child: Text('Memory Legend', style: legendHeading),
              ),
              legendRow(name1: 'Capacity', image1: capacityLegend),
              legendRow(name1: 'Used', image1: usedLegend),
              legendRow(name1: 'External', image1: externalLegend),
              legendRow(name1: 'RSS', image1: rssLegend),
              if (controller.isAndroidChartVisible)
                const Padding(padding: EdgeInsets.fromLTRB(0, 0, 0, 9)),
              if (controller.isAndroidChartVisible)
                Container(
                  padding: const EdgeInsets.fromLTRB(5, 0, 0, 4),
                  child: Text('Android Legend', style: legendHeading),
                ),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Total', image1: androidTotalLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Other', image1: androidOtherLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Code', image1: androidCodeLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Native', image1: androidNativeLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Java', image1: androidJavaLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Stack', image1: androidStackLegend),
              if (controller.isAndroidChartVisible)
                legendRow(name1: 'Graphics', image1: androidGraphicsLegend),
            ],
          ),
        ),
      ),
    );

    overlayState.insert(legendOverlayEntry);
  }

  void hideLegend() {
    legendOverlayEntry?.remove();
    legendOverlayEntry = null;
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

    // Remove history of all plotted data in all charts.
    eventChartController?.reset();
    vmChartController?.reset();
    androidChartController?.reset();
  }

  Future<void> _gc() async {
    // TODO(terry): Record GC in analytics.
    try {
      debugLogger('User Initiated GC Start');

      // TODO(terry): Only record GCs not when user initiated.
      controller.memoryTimeline.addGCEvent();

      await controller.gc();

      debugLogger('User GC Complete');
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }
}
