// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

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
import '../dialogs.dart';
import '../globals.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/icons.dart';
import '../ui/utils.dart';
import '../utils.dart';

import 'memory_android_chart.dart' as android;
import 'memory_controller.dart';
import 'memory_events_pane.dart' as events;
import 'memory_heap_tree_view.dart';
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

  @visibleForTesting
  static const isDebugging = isDebuggingEnabled;

  /// Do not checkin with field set to true, only for local debugging.
  static const isDebuggingEnabled = false;

  static const id = 'memory';

  static const legendKeyName = 'Legend Button';
  static const hoverKeyName = 'Chart Hover';

  @visibleForTesting
  static const pauseButtonKey = Key('Pause Button');
  @visibleForTesting
  static const resumeButtonKey = Key('Resume Button');
  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const intervalDropdownKey = Key('ChartInterval Dropdown');
  @visibleForTesting
  static const intervalMenuItem = Key('ChartInterval Menu Item');
  @visibleForTesting
  static const intervalKey = Key('ChartInterval');

  @visibleForTesting
  static const sourcesDropdownKey = Key('Sources Dropdown');
  @visibleForTesting
  static const sourcesMenuItemKey = Key('Sources Menu Item');
  @visibleForTesting
  static const sourcesKey = Key('Sources');
  @visibleForTesting
  static const exportButtonKey = Key('Export Button');
  @visibleForTesting
  static const gcButtonKey = Key('GC Button');
  @visibleForTesting
  static const legendButtonkey = Key(legendKeyName);
  @visibleForTesting
  static const settingsButtonKey = Key('Memory Configuration');

  @visibleForTesting
  static const eventChartKey = Key('EventPane');
  @visibleForTesting
  static const vmChartKey = Key('VMChart');
  @visibleForTesting
  static const androidChartKey = Key('AndroidChart');

  @visibleForTesting
  static const androidChartButtonKey = Key('Android Memory');

  static const memorySourceMenuItemPrefix = 'Source: ';

  static void gaAction({Key key, String name}) {
    final recordName = key != null ? keyName(key) : name;
    assert(recordName != null);
    ga.select(MemoryScreen.id, recordName);
  }

  // Define here because exportButtonKey is @visibleForTesting and
  // and can't be ref'd outside of file.
  static void gaActionForExport() {
    gaAction(key: exportButtonKey);
  }

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const MemoryBody();
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  static const List<Tab> memoryTabs = [
    Tab(text: 'Analysis'),
    Tab(text: 'Allocations'),
  ];

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  events.EventChartController eventChartController;
  vm.VMChartController vmChartController;
  android.AndroidChartController androidChartController;

  MemoryController controller;

  OverlayEntry hoverOverlayEntry;
  OverlayEntry legendOverlayEntry;

  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool isAndroidCollection = MemoryController.androidADBDefault;

  @override
  void initState() {
    super.initState();
    ga.screen(MemoryScreen.id);
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
        if (controller.isLegendVisible) {
          MemoryScreen.gaAction(key: MemoryScreen.legendButtonkey);
          showLegend(context);
        } else {
          hideLegend();
        }
      });
    });

    addAutoDisposeListener(controller.androidChartVisibleNotifier, () {
      setState(() {
        if (controller.androidChartVisibleNotifier.value) {
          MemoryScreen.gaAction(key: MemoryScreen.androidChartButtonKey);
        }
        if (controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          hideLegend();
          showLegend(context);
        }
      });
    });

    addAutoDisposeListener(eventChartController.tapLocation, () {
      if (eventChartController.tapLocation.value != null) {
        if (hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = eventChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation;
          final index = tapData.index;
          final timestamp = tapData.timestamp;

          final copied = TapLocation.copy(tapLocation);
          vmChartController.tapLocation.value = copied;
          androidChartController.tapLocation.value = copied;

          final allValues = ChartsValues(controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('Event Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails.globalPosition);
        }
      }
    });

    addAutoDisposeListener(vmChartController.tapLocation, () {
      if (vmChartController.tapLocation.value != null) {
        if (hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = vmChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation;
          final index = tapData.index;
          final timestamp = tapData.timestamp;

          final copied = TapLocation.copy(tapLocation);
          eventChartController.tapLocation.value = copied;
          androidChartController.tapLocation.value = copied;

          final allValues = ChartsValues(controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('VM Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails.globalPosition);
        }
      }
    });

    addAutoDisposeListener(androidChartController.tapLocation, () {
      if (androidChartController.tapLocation.value != null) {
        if (hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = androidChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation;
          final index = tapData.index;
          final timestamp = tapData.timestamp;

          final copied = TapLocation.copy(tapLocation);
          eventChartController.tapLocation.value = copied;
          vmChartController.tapLocation.value = copied;

          final allValues = ChartsValues(controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('Android Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails.globalPosition);
        }
      }
    });

    addAutoDisposeListener(controller.androidCollectionEnabled, () {
      isAndroidCollection = controller.androidCollectionEnabled.value;
      setState(() {
        if (!isAndroidCollection && controller.isAndroidChartVisible) {
          // If we're no longer collecting android stats then hide the
          // chart and disable the Android Memory button.
          controller.toggleAndroidChartVisibility();
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

    // TODO(terry): Can Flutter's focus system be used instead of listening to keyboard?
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
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
          const SizedBox(height: denseRowSpacing),
          SizedBox(
            height: 70,
            child: events.MemoryEventsPane(
              eventChartController,
              key: MemoryScreen.eventChartKey,
            ),
          ),
          SizedBox(
            child: vm.MemoryVMChart(
              vmChartController,
              key: MemoryScreen.vmChartKey,
            ),
          ),
          controller.isAndroidChartVisible
              ? SizedBox(
                  height: defaultChartHeight,
                  child: android.MemoryAndroidChart(
                    androidChartController,
                    key: MemoryScreen.androidChartKey,
                  ),
                )
              : const SizedBox(),
          const SizedBox(width: defaultSpacing),
          Expanded(
            child: HeapTree(controller),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    hideHover(); // hover will leak if not hide
    super.dispose();
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
        key: MemoryScreen.intervalDropdownKey,
        style: textTheme.bodyText2,
        value: displayDuration(controller.displayInterval),
        onChanged: (String newValue) {
          setState(() {
            MemoryScreen.gaAction(key: MemoryScreen.intervalDropdownKey);
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
        key: MemoryScreen.sourcesMenuItemKey,
        value: value,
        child: Text(
          '${controller.memorySourcePrefix}$displayValue',
          key: MemoryScreen.sourcesKey,
        ),
      );
    }).toList();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: MemoryScreen.sourcesDropdownKey,
        style: textTheme.bodyText2,
        value: controller.memorySource,
        onChanged: (String newValue) {
          setState(() {
            MemoryScreen.gaAction(key: MemoryScreen.sourcesDropdownKey);
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
            ClearButton(
              key: MemoryScreen.clearButtonKey,
              // TODO(terry): Button needs to be Delete for offline data.
              onPressed: controller.memorySource == MemoryController.liveFeed
                  ? _clearTimeline
                  : null,
              includeTextWidth: _primaryControlsMinVerboseWidth,
            ),
            const SizedBox(width: defaultSpacing),
            _intervalDropdown(textTheme),
          ],
        );
      },
    );
  }

  Widget createToggleAdbMemoryButton() {
    return IconLabelButton(
      key: MemoryScreen.androidChartButtonKey,
      icon: controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
      label: keyName(MemoryScreen.androidChartButtonKey),
      onPressed: controller.isConnectedDeviceAndroid && isAndroidCollection
          ? controller.toggleAndroidChartVisibility
          : null,
      includeTextWidth: 900,
    );
  }

  Widget _buildMemoryControls(TextTheme textTheme) {
    return Row(
      children: [
        _memorySourceDropdown(textTheme),
        const SizedBox(width: defaultSpacing),
        createToggleAdbMemoryButton(),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          key: MemoryScreen.gcButtonKey,
          onPressed: controller.isGcing ? null : _gc,
          icon: Icons.delete,
          label: 'GC',
          includeTextWidth: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: defaultSpacing),
        IconLabelButton(
          key: MemoryScreen.exportButtonKey,
          onPressed:
              controller.offline ? null : controller.memoryLog.exportMemory,
          icon: Icons.file_download,
          label: 'Export',
          includeTextWidth: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: defaultSpacing),
        IconLabelButton(
          key: legendKey,
          onPressed: controller.toggleLegendVisibility,
          icon: legendOverlayEntry == null ? Icons.storage : Icons.close,
          label: 'Legend',
          includeTextWidth: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
          tooltip: 'Memory Configuration',
        ),
      ],
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MemoryConfigurationsDialog(controller),
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
  static const hoverWidth = 203.0;
  static const hover_card_border_width = 2.0;

  // TODO(terry): Compute below heights dynamically.
  static const hoverHeightMinimum = 40.0;
  static const hoverItemHeight = 18.0;
  static const hoverOneEventsHeight =
      82.0; // One extension event to display (3 lines).
  static const hoverEventsHeight = 120.0; // Many extension events to display.

  static double computeHoverHeight(
    int eventsCount,
    int tracesCount,
    int extensionEventsCount,
  ) =>
      hoverHeightMinimum +
      (eventsCount * hoverItemHeight) +
      hover_card_border_width +
      (tracesCount * hoverItemHeight) +
      (extensionEventsCount > 0
          ? (extensionEventsCount == 1
              ? hoverOneEventsHeight
              : hoverEventsHeight)
          : 0);

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
  static const rasterLayerLegend = '${base}layer_glyph.png';
  static const rasterPictureLegend = '${base}picture_glyph.png';

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
    bool hasUnit = false,
    bool scaleImage = false,
    double leftPadding = 5.0,
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
        int startOfNumber = name.lastIndexOf(' ');
        if (hasUnit) {
          final unitOrValue = name.substring(startOfNumber + 1);
          if (int.tryParse(unitOrValue) == null) {
            // Got a unit.
            startOfNumber = name.lastIndexOf(' ', startOfNumber - 1);
          }
        }
        displayName = '${name.substring(0, startOfNumber)} ';
        displayValue = name.substring(startOfNumber + 1);
      }
      return [
        image == null
            ? const SizedBox()
            : scaleImage
                ? Image(image: AssetImage(image), width: 20, height: 10)
                : Image(image: AssetImage(image)),
        const PaddedDivider(
          padding: EdgeInsets.only(left: denseRowSpacing),
        ),
        Text(displayName, style: bold ? hoverTitleEntry : hoverSmallEntry),
        Text(displayValue, style: hoverValueEntry)
      ];
    }

    final rowChildren = <Widget>[];
    rowChildren.addAll(hoverPart(name, image, leftPadding));
    return Container(
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 2),
        child: Row(
          children: rowChildren,
        ));
  }

  /// Display name is either '1 Event' or 'n Events'
  static const eventDisplayName = ' Event';
  static const eventsDisplayName = ' Events';

  List<Widget> displayExtensionEventsInHover(ChartsValues chartsValues) {
    final widgets = <Widget>[];
    final eventsDisplayed = <String, String>{};

    if (chartsValues.hasExtensionEvents) {
      final eventLength = chartsValues.extensionEventsLength;
      if (eventLength > 0) {
        final displayKey = '$eventLength'
            '${eventLength == 1 ? eventDisplayName : eventsDisplayName}';
        eventsDisplayed[displayKey] =
            eventLength == 1 ? eventLegend : eventsLegend;
      }
    }

    for (var entry in eventsDisplayed.entries) {
      if (entry.key.endsWith(eventsDisplayName)) {
        widgets.add(Container(
          height: 120,
          child: ListView(
            shrinkWrap: true,
            primary: false,
            children: [
              listItem(
                events: chartsValues.extensionEvents,
                title: entry.key,
                icon: Icons.dashboard,
              ),
            ],
          ),
        ));
      } else {
        widgets.add(hoverRow(name: entry.key, image: entry.value));

        /// Pull out the event name, and custom values.
        final output = displayEvent(null, chartsValues.extensionEvents.first);
        widgets.add(hoverRow(name: output, bold: false, leftPadding: 0.0));
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

  // TODO(terry): Data could be long need better mechanism for long data e.g.,:
  //                const encoder = JsonEncoder.withIndent('  ');
  //                final displayData = encoder.convert(data);
  String longValueToShort(String longValue) {
    var value = longValue;
    if (longValue.length > 35) {
      final firstPart = longValue.substring(0, 10);
      final endPart = longValue.substring(longValue.length - 20);
      value = '$firstPart...$endPart';
    }
    return value;
  }

  String decodeEventValues(Map<String, Object> event) {
    final output = StringBuffer();
    if (event[eventName] == imageSizesForFrameEvent) {
      // TODO(terry): Need a more generic event displayer.
      // Flutter event emit the event name and value.
      final Map<String, Object> data = event[eventData];
      final key = data.keys.first;
      output.writeln('${longValueToShort(key)}');
      final Map values = data[key];
      final displaySize = values[displaySizeInBytesData];
      final decodeSize = values[decodedSizeInBytesData];
      final outputSizes = '$displaySize/$decodeSize';
      if (outputSizes.length > 10) {
        output.writeln('Display/Decode Size=');
        output.writeln('    $outputSizes');
      } else {
        output.writeln('Display/Decode Size=$outputSizes');
      }
    } else if (event[eventName] == devToolsEvent &&
        event.containsKey(customEvent)) {
      final Map custom = event[customEvent];
      final data = custom[customEventData];
      for (var key in data.keys) {
        output.write('$key=');
        output.writeln('${longValueToShort(data[key])}');
      }
    } else {
      output.writeln('Unknown Event ${event[eventName]}');
    }

    return output.toString();
  }

  String displayEvent(int index, Map<String, Object> event) {
    final output = StringBuffer();

    String name;

    if (event[eventName] == devToolsEvent && event.containsKey(customEvent)) {
      final Map custom = event[customEvent];
      name = custom[customEventName];
    } else {
      name = event[eventName];
    }

    output.writeln(index == null ? name : '$index. $name');
    output.writeln(decodeEventValues(event));

    return output.toString();
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

    final colorScheme = Theme.of(context).colorScheme;
    final hoverTextStyle = colorScheme.hoverTextStyle;
    final contrastForeground = colorScheme.contrastForeground;
    final collapsedColor = colorScheme.defaultBackgroundColor;

    return Material(
      color: Colors.transparent,
      child: Theme(
        data: ThemeData(unselectedWidgetColor: contrastForeground),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.fromLTRB(5, 4, 0, 0),
            child: Image(
              image: events.length > 1
                  ? const AssetImage(eventsLegend)
                  : const AssetImage(eventLegend),
            ),
          ),
          backgroundColor: collapsedColor,
          collapsedBackgroundColor: collapsedColor,
          title: Text(title, style: hoverTextStyle),
          children: widgets,
        ),
      ),
    );
  }

  Widget cardWidget(String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoverValueEntry = colorScheme.hoverSmallValueTextStyle;
    final expandedGradient = colorScheme.verticalGradient;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: hoverWidth,
        decoration: BoxDecoration(
          gradient: expandedGradient,
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

  String formatNumeric(num number) => controller.unitDisplayed.value
      ? prettyPrintBytes(
          number,
          kbFractionDigits: 1,
          mbFractionDigits: 2,
          includeUnit: true,
          roundingPoint: 0.7,
        )
      : nf.format(number);

  List<Widget> displayVmDataInHover(ChartsValues chartsValues) {
    const rssDisplay = 'RSS';
    const capacityDisplay = 'Capacity';
    const usedDisplay = 'Used';
    const externalDisplay = 'External';
    const layerDisplay = 'Raster Layer';
    const pictureDisplay = 'Raster Picture';

    final results = <Widget>[];

    final vmDataDisplayed = <String, String>{};

    final data = chartsValues.vmData;

    final rssValueDisplay = formatNumeric(data[rssJsonName]);
    vmDataDisplayed['$rssDisplay $rssValueDisplay'] = rssLegend;

    final capacityValueDisplay = formatNumeric(data[capacityJsonName]);
    vmDataDisplayed['$capacityDisplay $capacityValueDisplay'] = capacityLegend;

    final usedValueDisplay = formatNumeric(data[usedJsonName]);
    vmDataDisplayed['$usedDisplay $usedValueDisplay'] = usedLegend;

    final externalValueDisplay = formatNumeric(data[externalJsonName]);
    vmDataDisplayed['$externalDisplay $externalValueDisplay'] = externalLegend;

    final layerValueDisplay = formatNumeric(data[rasterLayerJsonName]);
    vmDataDisplayed['$layerDisplay $layerValueDisplay'] = rasterLayerLegend;

    final pictureValueDisplay = formatNumeric(data[rasterPictureJsonName]);
    vmDataDisplayed['$pictureDisplay $pictureValueDisplay'] =
        rasterPictureLegend;

    for (var entry in vmDataDisplayed.entries) {
      results.add(
        hoverRow(
          name: entry.key,
          image: entry.value,
          hasNumeric: true,
          hasUnit: controller.unitDisplayed.value,
          scaleImage: true,
        ),
      );
    }

    return results;
  }

  List<Widget> displayAndroidDataInHover(ChartsValues chartsValues) {
    const totalDisplay = 'Total';
    const otherDisplay = 'Other';
    const codeDisplay = 'Code';
    const nativeDisplay = 'Native';
    const javaDisplay = 'Java';
    const stackDisplay = 'Stack';
    const graphicsDisplay = 'Graphics';

    final results = <Widget>[];

    if (controller.isAndroidChartVisible) {
      final androidDataDisplayed = <String, String>{};

      final data = chartsValues.androidData;

      final totalValueDisplay = formatNumeric(data[adbTotalJsonName]);
      androidDataDisplayed['$totalDisplay $totalValueDisplay'] =
          androidTotalLegend;

      final otherValueDisplay = formatNumeric(data[adbOtherJsonName]);
      androidDataDisplayed['$otherDisplay $otherValueDisplay'] =
          androidOtherLegend;

      final codeValueDisplay = formatNumeric(data[adbCodeJsonName]);
      androidDataDisplayed['$codeDisplay $codeValueDisplay'] =
          androidCodeLegend;

      final nativeValueDisplay = formatNumeric(data[adbNativeHeapJsonName]);
      androidDataDisplayed['$nativeDisplay $nativeValueDisplay'] =
          androidNativeLegend;

      final javaValueDisplay = formatNumeric(data[adbJavaHeapJsonName]);
      androidDataDisplayed['$javaDisplay $javaValueDisplay'] =
          androidJavaLegend;

      final stackValueDisplay = formatNumeric(data[adbStackJsonName]);
      androidDataDisplayed['$stackDisplay $stackValueDisplay'] =
          androidStackLegend;

      final graphicsValueDisplay = formatNumeric(data[adbGraphicsJsonName]);
      androidDataDisplayed['$graphicsDisplay $graphicsValueDisplay'] =
          androidGraphicsLegend;

      for (var entry in androidDataDisplayed.entries) {
        results.add(
          hoverRow(
            name: entry.key,
            image: entry.value,
            hasNumeric: true,
            hasUnit: controller.unitDisplayed.value,
            scaleImage: true,
          ),
        );
      }
    }

    return results;
  }

  void showHover(
    BuildContext context,
    ChartsValues chartsValues,
    Offset position,
  ) {
    final focusColor = Theme.of(context).focusColor;
    final colorScheme = Theme.of(context).colorScheme;

    final RenderBox box = hoverKey.currentContext.findRenderObject();
    final renderBoxWidth = box.size.width;

    // Display hover to left of right side of position.
    double xPosition = position.dx + hoverXOffset;
    if (xPosition + hoverWidth > renderBoxWidth) {
      xPosition = position.dx - hoverWidth - hoverXOffset;
    }

    double totalHoverHeight;
    int totalTraces;
    if (controller.isAndroidChartVisible) {
      totalTraces = chartsValues.vmData.entries.length -
          1 +
          chartsValues.androidData.entries.length;
    } else {
      totalTraces = chartsValues.vmData.entries.length - 1;
    }

    totalHoverHeight = computeHoverHeight(
      chartsValues.eventCount,
      totalTraces,
      chartsValues.extensionEventsLength,
    );

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
            color: colorScheme.defaultBackgroundColor,
            border: Border.all(
              color: focusColor,
              width: hover_card_border_width,
            ),
            borderRadius: BorderRadius.circular(10.0),
          ),
          width: hoverWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: hoverWidth,
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Time $displayTimestamp',
                  style: hoverHeading,
                  textAlign: TextAlign.center,
                ),
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
    if (hoverOverlayEntry != null) {
      eventChartController.tapLocation.value = null;
      vmChartController.tapLocation.value = null;
      androidChartController.tapLocation.value = null;

      hoverOverlayEntry?.remove();
      hoverOverlayEntry = null;
    }
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
    MemoryScreen.gaAction(key: MemoryScreen.clearButtonKey);

    controller.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    controller.monitorAllocations = [];
    controller.monitorTimestamp = null;
    controller.lastMonitorTimestamp.value = null;
    controller.trackAllocations.clear();
    controller.allocationSamples.clear();

    // Clear all analysis and snapshots collected too.
    controller.clearAllSnapshots();
    controller.classRoot = null;
    controller.topNode = null;
    controller.selectedSnapshotTimestamp = null;
    controller.selectedLeaf = null;

    // Remove history of all plotted data in all charts.
    eventChartController?.reset();
    vmChartController?.reset();
    androidChartController?.reset();
  }

  Future<void> _gc() async {
    try {
      MemoryScreen.gaAction(key: MemoryScreen.gcButtonKey);

      controller.memoryTimeline.addGCEvent();

      await controller.gc();
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }
}

/// Event types handled for hover card.
const devToolsEvent = 'DevTools.Event';
const imageSizesForFrameEvent = 'Flutter.ImageSizesForFrame';
const displaySizeInBytesData = 'displaySizeInBytes';
const decodedSizeInBytesData = 'decodedSizeInBytes';

const String eventName = 'name';
const String eventData = 'data';
const String customEvent = 'custom';
const String customEventName = 'name';
const String customEventData = 'data';

const String indexPayloadJson = 'index';
const String timestampPayloadJson = 'timestamp';
const String prettyTimestampPayloadJson = 'prettyTimestamp';
const String eventPayloadJson = 'event';
const String vmPayloadJson = 'vm';
const String androidPayloadJson = 'android';

/// VM Data
const String rssJsonName = 'rss';
const String capacityJsonName = 'capacity';
const String usedJsonName = 'used';
const String externalJsonName = 'external';
const String rasterPictureJsonName = 'rasterLayer';
const String rasterLayerJsonName = 'rasterPicture';

/// Android data
const String adbTotalJsonName = 'total';
const String adbOtherJsonName = 'other';
const String adbCodeJsonName = 'code';
const String adbNativeHeapJsonName = 'nativeHeap';
const String adbJavaHeapJsonName = 'javaHeap';
const String adbStackJsonName = 'stack';
const String adbGraphicsJsonName = 'graphics';

/// Events data
const String snapshotJsonName = 'snapshot';
const String autoSnapshotJsonName = 'autoSnapshot';
const String monitorStartJsonName = 'monitorStart';
const String monitorResetJsonName = 'monitorReset';
const String extensionEventsJsonName = 'extensionEvents';
const String manualGCJsonName = 'manualGC';
const String gcJsonName = 'gc';

/// Retrieve all data values of a given index (timestamp) of the collected data.
class ChartsValues {
  ChartsValues(this.controller, this.index, this.timestamp) {
    _fetch();
  }

  final MemoryController controller;

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
      indexPayloadJson: index,
      timestampPayloadJson: timestamp,
      prettyTimestampPayloadJson: prettyTimestamp(timestamp),
      eventPayloadJson: _event,
      vmPayloadJson: _vm,
      androidPayloadJson: _android,
    };
  }

  int get eventCount =>
      _event.entries.length -
      (extensionEventsLength > 0 ? 1 : 0) +
      (hasGc ? 1 : 0);

  bool get hasSnapshot => _event.containsKey(snapshotJsonName);
  bool get hasAutoSnapshot => _event.containsKey(autoSnapshotJsonName);
  bool get hasMonitorStart => _event.containsKey(monitorStartJsonName);
  bool get hasMonitorReset => _event.containsKey(monitorResetJsonName);
  bool get hasExtensionEvents => _event.containsKey(extensionEventsJsonName);
  bool get hasManualGc => _event.containsKey(manualGCJsonName);
  bool get hasGc => _vm[gcJsonName];

  int get extensionEventsLength =>
      hasExtensionEvents ? extensionEvents.length : 0;

  List<Map<String, Object>> get extensionEvents {
    if (_extensionEvents.isEmpty) {
      _extensionEvents.addAll(_event[extensionEventsJsonName]);
    }
    return _extensionEvents;
  }

  void _fetch() {
    _event.clear();
    _vm.clear();
    _android.clear();

    _fetchEventData(_event);
    _fetchVMData(controller.memoryTimeline.data[index], _vm);
    _fetchAndroidData(
      controller.memoryTimeline.data[index].adbMemoryInfo,
      _android,
    );
  }

  void _fetchEventData(Map<String, Object> results) {
    // Use the detailed extension events data stored in the memoryTimeline.
    final eventInfo = controller.memoryTimeline.data[index].memoryEventInfo;

    if (eventInfo.isEmpty) return;

    if (eventInfo.isEventGC) results[manualGCJsonName] = true;
    if (eventInfo.isEventSnapshot) results[snapshotJsonName] = true;
    if (eventInfo.isEventSnapshotAuto) results[autoSnapshotJsonName] = true;
    if (eventInfo.isEventAllocationAccumulator) {
      if (eventInfo.allocationAccumulator.isStart) {
        results[monitorStartJsonName] = true;
      }
      if (eventInfo.allocationAccumulator.isReset) {
        results[monitorResetJsonName] = true;
      }
    }

    if (eventInfo.hasExtensionEvents) {
      final events = <Map<String, Object>>[];
      for (ExtensionEvent event in eventInfo.extensionEvents.theEvents) {
        if (event.customEventName != null) {
          events.add(
            {
              eventName: event.eventKind,
              customEvent: {
                customEventName: event.customEventName,
                customEventData: event.data,
              },
            },
          );
        } else {
          events.add({eventName: event.eventKind, eventData: event.data});
        }
      }
      if (events.isNotEmpty) {
        results[extensionEventsJsonName] = events;
      }
    }
  }

  void _fetchVMData(HeapSample heapSample, Map<String, Object> results) {
    results[rssJsonName] = heapSample.rss;
    results[capacityJsonName] = heapSample.capacity;
    results[usedJsonName] = heapSample.used;
    results[externalJsonName] = heapSample.external;
    results[gcJsonName] = heapSample.isGC;
    results[rasterPictureJsonName] = heapSample.rasterCache.pictureBytes;
    results[rasterLayerJsonName] = heapSample.rasterCache.layerBytes;
  }

  void _fetchAndroidData(
    AdbMemoryInfo androidData,
    Map<String, Object> results,
  ) {
    results[adbTotalJsonName] = androidData.total;
    results[adbOtherJsonName] = androidData.other;
    results[adbCodeJsonName] = androidData.code;
    results[adbNativeHeapJsonName] = androidData.nativeHeap;
    results[adbJavaHeapJsonName] = androidData.javaHeap;
    results[adbStackJsonName] = androidData.stack;
    results[adbGraphicsJsonName] = androidData.graphics;
  }
}

class MemoryConfigurationsDialog extends StatelessWidget {
  const MemoryConfigurationsDialog(this.controller);

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Memory Settings'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dialogSubHeader(theme, 'Android'),
            Column(
              children: [
                Row(
                  children: [
                    NotifierCheckbox(
                        notifier: controller.androidCollectionEnabled),
                    RichText(
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        text: 'Collect Android Memory Statistics using ADB',
                        style: theme.regularTextStyle,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    NotifierCheckbox(notifier: controller.unitDisplayed),
                    RichText(
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        text: 'Display Data In Units (B, KB, MB, and GB)',
                        style: theme.regularTextStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}
