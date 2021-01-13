// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../charts/chart_controller.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../octicons.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/label.dart';
import '../utils.dart';

import 'memory_android_chart.dart' as android;
import 'memory_controller.dart';
import 'memory_events_pane.dart' as events;
import 'memory_heap_tree_view.dart';
import 'memory_heap_treemap.dart';
import 'memory_vm_chart.dart' as vm;

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
  static const hoverKeyName = 'Chart Hover';

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

  events.EventChartController eventChartController;
  vm.VMChartController vmChartController;
  android.AndroidChartController androidChartController;

  MemoryController controller;
  TabController tabController;

  OverlayEntry hoverOverlayEntry;
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

    eventChartController = events.EventChartController(controller);
    vmChartController = vm.VMChartController(controller);
    // Android Chart uses the VM Chart's computed labels.
    androidChartController = android.AndroidChartController(
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

    addAutoDisposeListener(eventChartController.tapNotifier, () {
      if (!eventChartController.tapNotifier.value.isEmpty &&
          hoverOverlayEntry != null) {
        hideHover();
      }
      if (eventChartController.tapNotifier.value.tapDownDetails != null) {
        final tapData = eventChartController.tapNotifier.value;
        final index = tapData.index;
        final timestamp = tapData.timestamp;

        final copied = TapNotifier.copy(eventChartController.tapNotifier.value);
        vmChartController.setTapNotifier(copied);
        androidChartController.setTapNotifier(copied);

        final allValues = ChartsValues(this, index, timestamp);
        if (isDebugging) {
          print('Event Chart TapNotifier '
              '${JsonUtils.prettyPrint(allValues.toJson())}');
        }
        showHover(context, allValues, tapData.tapDownDetails.globalPosition);
      }
    });

    addAutoDisposeListener(vmChartController.tapNotifier, () {
      if (!vmChartController.tapNotifier.value.isEmpty &&
          hoverOverlayEntry != null) {
        hideHover();
      }
      if (vmChartController.tapNotifier.value.tapDownDetails != null) {
        final tapData = vmChartController.tapNotifier.value;
        final index = tapData.index;
        final timestamp = tapData.timestamp;

        final copied = TapNotifier.copy(vmChartController.tapNotifier.value);
        eventChartController.setTapNotifier(copied);
        androidChartController.setTapNotifier(copied);

        final allValues = ChartsValues(this, index, timestamp);
        if (isDebugging) {
          print('VM Chart TapNotifier '
              '${JsonUtils.prettyPrint(allValues.toJson())}');
        }
        showHover(context, allValues, tapData.tapDownDetails.globalPosition);
      }
    });

    addAutoDisposeListener(androidChartController.tapNotifier, () {
      if (!androidChartController.tapNotifier.value.isEmpty &&
          hoverOverlayEntry != null) {
        hideHover();
      }
      if (androidChartController.tapNotifier.value.tapDownDetails != null) {
        final tapData = androidChartController.tapNotifier.value;
        final index = tapData.index;
        final timestamp = tapData.timestamp;

        final copied =
            TapNotifier.copy(androidChartController.tapNotifier.value);
        eventChartController.setTapNotifier(copied);
        vmChartController.setTapNotifier(copied);

        final allValues = ChartsValues(this, index, timestamp);
        if (isDebugging) {
          print('Android Chart TapNotifier '
              '${JsonUtils.prettyPrint(allValues.toJson())}');
        }
        showHover(context, allValues, tapData.tapDownDetails.globalPosition);
      }
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
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
          eventChartController.setTapNotifier(TapNotifier.empty());
          vmChartController.setTapNotifier(TapNotifier.empty());
          androidChartController.setTapNotifier(TapNotifier.empty());
          hideHover();
        }
      },
      autofocus: true,
      child: Column(
        key: hoverKey,
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
            height: 70,
            child: events.MemoryEventsPane(eventChartController),
          ),
          SizedBox(
            child: vm.MemoryVMChart(vmChartController),
          ),
          controller.isAndroidChartVisible
              ? SizedBox(
                  height: defaultChartHeight,
                  child: android.MemoryAndroidChart(androidChartController),
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
      ),
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
            OutlinedButton(
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

  OutlinedButton createToggleAdbMemoryButton() {
    return OutlinedButton(
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
        OutlinedButton(
          key: MemoryScreen.gcButtonKey,
          onPressed: controller.isGcing ? null : _gc,
          child: const MaterialIconLabel(
            Icons.delete,
            'GC',
            includeTextWidth: _primaryControlsMinVerboseWidth,
          ),
        ),
        const SizedBox(width: defaultSpacing),
        OutlinedButton(
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
        OutlinedButton(
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

  final hoverKey = GlobalKey(debugLabel: MemoryScreen.hoverKeyName);
  static const hoverXOffset = 10;
  static const hoverYOffset = 0.0;
  static const hoverWidth = 240.0;
  // TODO(terry): Compute below heights dynamically.
  static const hoverHeight1Chart = 190.0;
  static const hoverHeight1ChartEvents = 270.0;
  static const hoverHeight2Charts = 330.0;
  static const hoverHeight2ChartsEvents = 395.0;

  // TODO(terry): Consider custom painter?
  static const base = 'assets/img/legend/';
  static const snapshotManualLegend = '${base}snapshot_manual_glyph.png';
  static const snapshotAutoLegend = '${base}snapshot_auto_glyph.png';
  static const monitorLegend = '${base}monitor_glyph.png';
  static const resetLegend = '${base}reset_glyph.png';
  static const gcManualLegend = '${base}gc_manual_glyph.png';
  static const gcVMLegend = '${base}gc_vm_glyph.png';
  static const eventLegend = '${base}event_glyph.png';
  static const eventsLegend = '${base}events_glyph.png';
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

  Widget hoverRow({
    String name,
    String image,
    bool bold = true,
    bool hasNumeric = false,
  }) {
    final hoverTitleEntry = Theme.of(context).colorScheme.hoverTextStyle;
    final hoverValueEntry = Theme.of(context).colorScheme.hoverValueTextStyle;
    final hoverSmallEntry =
        Theme.of(context).colorScheme.hoverSmallValueTextStyle;

    List<Widget> hoverPart(
      String name,
      String image, [
      double leftEdge = 5.0,
    ]) {
      String displayName = name;
      String displayValue = '';
      if (hasNumeric) {
        final lastSpaceBeforeValue = name.lastIndexOf(' ');
        displayName = '${name.substring(0, lastSpaceBeforeValue)} = ';
        displayValue = name.substring(lastSpaceBeforeValue + 1);
      }
      return [
        image == null ? const SizedBox() : Image(image: AssetImage(image)),
        const PaddedDivider(
          padding: EdgeInsets.only(left: denseRowSpacing),
        ),
        Text(displayName, style: bold ? hoverTitleEntry : hoverSmallEntry),
        Text(displayValue, style: hoverValueEntry)
      ];
    }

    final rowChildren = <Widget>[];
    rowChildren.addAll(hoverPart(name, image));
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 2),
        child: Row(
          children: rowChildren,
        ));
  }

  List<Widget> displayExtensionEventsInHover(ChartsValues chartsValues) {
    final widgets = <Widget>[];
    final eventsDisplayed = <String, String>{};

    if (chartsValues.hasExtensionEvents) {
      final eventLength = chartsValues.extensionEventsLength;
      if (eventLength > 0) {
        final displayKey = '$eventLength Event${eventLength == 1 ? "" : "s"}';
        eventsDisplayed[displayKey] =
            eventLength == 1 ? eventLegend : eventsLegend;
      }
    }

    for (var entry in eventsDisplayed.entries) {
      if (entry.key.endsWith(' Events')) {
        widgets.add(Container(
          height: 120,
          child: ListView(
            shrinkWrap: true,
            primary: false,
            children: [
              listItem(
                  events: chartsValues.extensionEvents,
                  title: entry.key,
                  icon: Icons.dashboard_rounded),
            ],
          ),
        ));
      } else {
        widgets.add(hoverRow(name: entry.key, image: entry.value));

        /// Pull out the event name, and custom values.
        final output = displayEvent(null, chartsValues.extensionEvents.first);
        widgets.add(hoverRow(name: output, bold: false));
      }
    }
    return widgets;
  }

  List<Widget> displayEventsInHover(ChartsValues chartsValues) {
    final results = <Widget>[];

    final eventsDisplayed = <String, String>{};

    if (chartsValues.hasSnapshot) {
      eventsDisplayed['Snapshot'] = snapshotManualLegend;
    } else if (chartsValues.hasAutoSnapshot) {
      eventsDisplayed['Auto Snapshot'] = snapshotAutoLegend;
    } else if (chartsValues.hasMonitorStart) {
      eventsDisplayed['Monitor Start'] = monitorLegend;
    } else if (chartsValues.hasMonitorReset) {
      eventsDisplayed['Monitor Reset'] = resetLegend;
    }

    if (chartsValues.hasGc) {
      eventsDisplayed['GC'] = gcVMLegend;
    }

    if (chartsValues.hasManualGc) {
      eventsDisplayed['User GC'] = gcManualLegend;
    }

    for (var entry in eventsDisplayed.entries) {
      Widget widget;

      widget = hoverRow(name: entry.key, image: entry.value);
      results.add(widget);
    }

    return results;
  }

  String displayEvent(int index, Map<String, Object> event) {
    if (event['name'] == 'DevTools.Event' && event.containsKey('custom')) {
      final Map custom = event['custom'];
      final String eventName = custom['name'];
      final Map data = custom['data'];
      // TODO(terry): Data could be long need better mechanism for long data e.g.,:
      //                const encoder = JsonEncoder.withIndent('  ');
      //                final displayData = encoder.convert(data);
      final output = StringBuffer();
      output.writeln(index == null ? eventName : '[$index] $eventName');
      for (var key in data.keys) {
        output.write(' $key=');
        var value = '';
        if (data[key].length > 35) {
          final longValue = data[key];
          final firstPart = longValue.substring(0, 10);
          final endPart = longValue.substring(longValue.length - 20);
          value = '$firstPart...$endPart';
        } else {
          value = data[key];
        }
        output.writeln(value);
      }
      return output.toString();
    } else {
      final eventName = event['name'];
      return index == null ? eventName : '[$index] $eventName';
    }
  }

  Widget listItem({
    List<Map<String, Object>> events,
    int index,
    String title,
    IconData icon,
  }) {
    final widgets = <Widget>[];
    var index = 1;
    for (var event in events) {
      final output = displayEvent(index, event);
      widgets.add(cardWidget(output));
      index++;
    }

    final hoverTitleEntry = Theme.of(context).colorScheme.hoverTextStyle;

    return Material(
      color: Colors.transparent,
      child: Theme(
        data: ThemeData(accentColor: Colors.black),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: Image(
            image: events.length > 1
                ? const AssetImage(eventsLegend)
                : const AssetImage(eventLegend),
          ),
          title: Text(title, style: hoverTitleEntry),
          children: widgets,
        ),
      ),
    );
  }

  Widget cardWidget(String value) {
    final hoverValueEntry =
        Theme.of(context).colorScheme.hoverSmallValueTextStyle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: hoverWidth,
        decoration: const BoxDecoration(
          color: Colors.white30,
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: hoverValueEntry,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> displayVmDataInHover(ChartsValues chartsValues) {
    final results = <Widget>[];

    final vmDataDisplayed = <String, String>{};

    final data = chartsValues.vmData;

    final rssValueDisplay = nf.format(data['rSS']);
    vmDataDisplayed['RSS $rssValueDisplay'] = rssLegend;

    final capacityValueDisplay = nf.format(data['capacity']);
    vmDataDisplayed['Capacity $capacityValueDisplay'] = capacityLegend;

    final usedValueDisplay = nf.format(data['used']);
    vmDataDisplayed['Used $usedValueDisplay'] = usedLegend;

    final externalValueDisplay = nf.format(data['external']);
    vmDataDisplayed['External $externalValueDisplay'] = externalLegend;

    for (var entry in vmDataDisplayed.entries) {
      results.add(hoverRow(
        name: entry.key,
        image: entry.value,
        hasNumeric: true,
      ));
    }

    return results;
  }

  List<Widget> displayAndroidDataInHover(ChartsValues chartsValues) {
    final results = <Widget>[];

    if (controller.isAndroidChartVisible) {
      final androidDataDisplayed = <String, String>{};

      final data = chartsValues.androidData;

      final totalValueDisplay = nf.format(data['total']);
      androidDataDisplayed['Total $totalValueDisplay'] = androidTotalLegend;

      final otherValueDisplay = nf.format(data['other']);
      androidDataDisplayed['Other $otherValueDisplay'] = androidOtherLegend;

      final codeValueDisplay = nf.format(data['code']);
      androidDataDisplayed['Code $codeValueDisplay'] = androidCodeLegend;

      final nativeValueDisplay = nf.format(data['nativeHeap']);
      androidDataDisplayed['Native $nativeValueDisplay'] = androidNativeLegend;

      final javaValueDisplay = nf.format(data['javaHeap']);
      androidDataDisplayed['Java $javaValueDisplay'] = androidJavaLegend;

      final stackValueDisplay = nf.format(data['stack']);
      androidDataDisplayed['Stack $stackValueDisplay'] = androidStackLegend;

      final graphicsValueDisplay = nf.format(data['graphics']);
      androidDataDisplayed['Graphics $graphicsValueDisplay'] =
          androidGraphicsLegend;

      for (var entry in androidDataDisplayed.entries) {
        results.add(hoverRow(
          name: entry.key,
          image: entry.value,
          hasNumeric: true,
        ));
      }
    }

    return results;
  }

  void showHover(
    BuildContext context,
    ChartsValues chartsValues,
    Offset position,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final RenderBox box = hoverKey.currentContext.findRenderObject();
    final renderBoxWidth = box.size.width;

    // Display hover to left of right side of position.
    double xPosition = position.dx + hoverXOffset;
    if (xPosition + hoverWidth > renderBoxWidth) {
      xPosition = position.dx - hoverWidth - hoverXOffset;
    }

    double totalHoverHeight;
    if (controller.isAndroidChartVisible) {
      totalHoverHeight = chartsValues.extensionEventsLength > 1
          ? hoverHeight2ChartsEvents
          : hoverHeight2Charts;
    } else {
      totalHoverHeight = chartsValues.extensionEventsLength > 1
          ? hoverHeight1ChartEvents
          : hoverHeight1Chart;
    }

    final displayTimestamp = prettyTimestamp(chartsValues.timestamp);

    final hoverHeading = colorScheme.hoverTitleTextStyle;
    final OverlayState overlayState = Overlay.of(context);
    hoverOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + hoverYOffset,
        left: xPosition,
        height: totalHoverHeight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 5, 0, 8),
          decoration: BoxDecoration(
            color: colorScheme.hoverBackgroundColor,
            border: Border.all(color: Colors.yellow),
            borderRadius: BorderRadius.circular(10.0),
          ),
          width: hoverWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 0, 4),
                child: Text('Time $displayTimestamp', style: hoverHeading),
              ),
            ]
              ..addAll(displayEventsInHover(chartsValues))
              ..addAll(displayVmDataInHover(chartsValues))
              ..addAll(displayAndroidDataInHover(chartsValues))
              ..addAll(displayExtensionEventsInHover(chartsValues)),
          ),
        ),
      ),
    );

    overlayState.insert(hoverOverlayEntry);
  }

  void hideHover() {
    hoverOverlayEntry?.remove();
    hoverOverlayEntry = null;
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

const String snapshotDisplayName = 'snapshot';
const String autoSnapshotDisplayName = 'autoSnapshot';
const String monitorStartDisplayName = 'monitorStart';
const String monitorResetDisplayName = 'monitorReset';
const String extensionEventsDisplayName = 'extensionEvents';
const String manualGCDisplayName = 'manualGC';
const String gcDisplayName = 'gc';

/// Retrieve all data values of a given index (timestamp) of the collected data.
class ChartsValues {
  ChartsValues(this.memoryState, this.index, this.timestamp) {
    _fetch();
  }

  final MemoryBodyState memoryState;

  final int index;

  final int timestamp;

  final _event = <String, Object>{};

  final _extensionEvents = <Map<String, Object>>[];

  Map<String, Object> get vmData => _vm;

  final _vm = <String, Object>{};

  Map<String, Object> get androidData => _android;

  final _android = <String, Object>{};

  Map<String, Object> toJson() {
    return {
      'index': index,
      'timestamp': timestamp,
      'prettyTimestamp': prettyTimestamp(timestamp),
      'event': _event,
      'vm': _vm,
      'android': _android,
    };
  }

  bool get hasSnapshot => _event.containsKey(snapshotDisplayName);
  bool get hasAutoSnapshot => _event.containsKey(autoSnapshotDisplayName);
  bool get hasMonitorStart => _event.containsKey(monitorStartDisplayName);
  bool get hasMonitorReset => _event.containsKey(monitorResetDisplayName);
  bool get hasExtensionEvents => _event.containsKey(extensionEventsDisplayName);
  bool get hasManualGc => _event.containsKey(manualGCDisplayName);
  bool get hasGc => _vm.containsKey(gcDisplayName);

  int get extensionEventsLength => hasExtensionEvents
      ? (_event[extensionEventsDisplayName] as List).length
      : 0;

  List<Map<String, Object>> get extensionEvents {
    if (_extensionEvents.isEmpty)
      _extensionEvents.addAll(_event[extensionEventsDisplayName]);
    return _extensionEvents;
  }

  void _fetch() {
    _event.clear();
    _vm.clear();
    _android.clear();

    _fetchEventData(_event);
    _fetchData(memoryState.vmChartController, _vm);
    _fetchData(memoryState.androidChartController, _android);
  }

  void _fetchEventData(Map<String, Object> results) {
    // Use the detailed extension events data stored in the memoryTimeline.
    final eventInfo =
        memoryState.controller.memoryTimeline.data[index].memoryEventInfo;

    if (eventInfo.isEmpty) return;

    if (eventInfo.isEventGC) results[manualGCDisplayName] = true;
    if (eventInfo.isEventSnapshot) results[snapshotDisplayName] = true;
    if (eventInfo.isEventSnapshotAuto) results[autoSnapshotDisplayName] = true;
    if (eventInfo.isEventAllocationAccumulator) {
      if (eventInfo.allocationAccumulator.isStart) {
        results[monitorStartDisplayName] = true;
      }
      if (eventInfo.allocationAccumulator.isReset) {
        results[monitorResetDisplayName] = true;
      }
    }

    if (eventInfo.hasExtensionEvents) {
      final List<Map<String, Object>> events = [];
      for (ExtensionEvent event in eventInfo.extensionEvents.theEvents) {
        if (event.customEventName != null) {
          events.add(
            {
              'name': event.eventKind,
              'custom': {
                'name': event.customEventName,
                'data': event.data,
              },
            },
          );
        } else {
          events.add(
            {
              'name': event.eventKind,
            },
          );
        }
      }
      if (events.isNotEmpty) {
        results[extensionEventsDisplayName] = events;
      }
    }
  }

  void _fetchData(
    ChartController chartController,
    Map<String, Object> results,
  ) {
    for (var trace in chartController.traces) {
      final theData = trace.data[index];
      final yValue = theData.y;

      // Convert enum'd string e.g., 'TraceName.capacity' to Map key'capacity', etc.
      results[trace.name.split('.').last] = yValue;
    }

    // VM GC.
    if (chartController is vm.VMChartController &&
        memoryState.controller.memoryTimeline.data[index].isGC) {
      results[gcDisplayName] = true;
    }
  }
}
