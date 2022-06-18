// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../analytics/analytics.dart' as ga;
import '../../charts/chart_controller.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/listenable.dart';
import '../../primitives/utils.dart';
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/notifications.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/icons.dart';
import 'memory_android_chart.dart' as android;
import 'memory_charts.dart';
import 'memory_controller.dart';
import 'memory_events_pane.dart' as events;
import 'memory_heap_tree_view.dart';
import 'memory_vm_chart.dart' as vm;
import 'panes/control/control_pane.dart';
import 'primitives/painting.dart';

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

  static const hoverKeyName = 'Chart Hover';

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

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

class MemoryBodyState extends State<MemoryBody>
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<MemoryController, MemoryBody> {
  late ChartControllers _chartControllers;

  MemoryController get memoryController => controller;

  OverlayEntry? _hoverOverlayEntry;

  final _focusNode = FocusNode(debugLabel: 'memory');

  @override
  void initState() {
    super.initState();
    ga.screen(MemoryScreen.id);
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModeMemoryMessage(context, MemoryScreen.id);
    if (!initController()) return;

    final vmChartController = vm.VMChartController(memoryController);

    _chartControllers = ChartControllers(
      event: events.EventChartController(memoryController),
      vm: vmChartController,
      android: android.AndroidChartController(
        memoryController,
        sharedLabels: vmChartController.labelTimestamps,
      ),
    );

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(memoryController.selectedSnapshotNotifier, () {
      setState(() {
        // TODO(terry): Create the snapshot data to display by Library,
        //              by Class or by Objects.
        // Create the snapshot data by Library.
        memoryController.createSnapshotByLibrary();
      });
    });

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(memoryController.memorySourceNotifier, () async {
      try {
        await memoryController.updatedMemorySource();
      } catch (e) {
        final errorMessage = '$e';
        memoryController.memorySource = MemoryController.liveFeed;
        // Display toast, unable to load the saved memory JSON payload.
        final notificationsState = Notifications.of(context);
        if (notificationsState != null) {
          notificationsState.push(errorMessage);
        } else {
          // Running in test harness, unexpected error.
          throw OfflineFileException(errorMessage);
        }
        return;
      }

      memoryController.refreshAllCharts();
    });

    addAutoDisposeListener(_chartControllers.event.tapLocation, () {
      if (_chartControllers.event.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _chartControllers.event.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _chartControllers.vm.tapLocation.value = copied;
          _chartControllers.android.tapLocation.value = copied;

          final allValues = ChartsValues(memoryController, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger(
              'Event Chart TapLocation '
              '${allValues.toJson().prettyPrint()}',
            );
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

    addAutoDisposeListener(_chartControllers.vm.tapLocation, () {
      if (_chartControllers.vm.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _chartControllers.vm.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _chartControllers.event.tapLocation.value = copied;
          _chartControllers.android.tapLocation.value = copied;

          final allValues = ChartsValues(memoryController, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger(
              'VM Chart TapLocation '
              '${allValues.toJson().prettyPrint()}',
            );
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

    addAutoDisposeListener(_chartControllers.android.tapLocation, () {
      if (_chartControllers.android.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _chartControllers.android.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _chartControllers.event.tapLocation.value = copied;
          _chartControllers.vm.tapLocation.value = copied;

          final allValues = ChartsValues(memoryController, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger(
              'Android Chart TapLocation '
              '${allValues.toJson().prettyPrint()}',
            );
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

    addAutoDisposeListener(memoryController.refreshCharts, () {
      setState(() {
        _refreshCharts();
      });
    });

    _updateListeningState();
  }

  @override
  Widget build(BuildContext context) {
    print('parent building. value is ' +
        controller.isAndroidChartVisibleNotifier.value.toString());
    // TODO(terry): Can Flutter's focus system be used instead of listening to keyboard?
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) {
        if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
          hideHover();
        }
      },
      autofocus: true,
      child: Column(
        key: hoverKey,
        children: [
          MemoryControlPane(chartControllers: _chartControllers),
          const SizedBox(height: denseRowSpacing),
          SizedBox(
            height: scaleByFontFactor(70),
            child: events.MemoryEventsPane(_chartControllers.event),
          ),
          SizedBox(
            child: vm.MemoryVMChart(_chartControllers.vm),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.isAndroidChartVisibleNotifier,
            builder: (context, isAndroidChartVisible, _) {
              print('child building. value is ' +
                  controller.isAndroidChartVisibleNotifier.value.toString());

              return isAndroidChartVisible
                  ? SizedBox(
                      height: defaultChartHeight,
                      child: android.MemoryAndroidChart(
                        _chartControllers.android,
                      ),
                    )
                  : const SizedBox();
            },
          ),
          const SizedBox(width: defaultSpacing),
          Expanded(
            child: HeapTree(memoryController),
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
    _chartControllers.event.reset();
    _chartControllers.vm.reset();
    _chartControllers.android.reset();

    _recomputeChartData();
  }

  /// Recompute (attach data to the chart) for either live or offline data source.
  void _recomputeChartData() {
    _chartControllers.event.setupData();
    _chartControllers.event.dirty = true;
    _chartControllers.vm.setupData();
    _chartControllers.vm.dirty = true;
    _chartControllers.android.setupData();
    _chartControllers.android.dirty = true;
  }

  void _updateListeningState() async {
    await serviceManager.onServiceAvailable;

    if (memoryController.hasStarted) return;

    await memoryController.startTimeline();

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

  final hoverKey = GlobalKey(debugLabel: MemoryScreen.hoverKeyName);
  static const hoverXOffset = 10;
  static const hoverYOffset = 0.0;
  static double get hoverWidth => scaleByFontFactor(225.0);
  static const hover_card_border_width = 2.0;

  // TODO(terry): Compute below heights dynamically.
  static double get hoverHeightMinimum => scaleByFontFactor(42.0);
  static double get hoverItemHeight => scaleByFontFactor(18.0);

  // One extension event to display (4 lines).
  static double get hoverOneEventsHeight => scaleByFontFactor(82.0);

  // Many extension events to display.
  static double get hoverEventsHeight => scaleByFontFactor(120.0);

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

  Widget hoverRow({
    required String name,
    String? image,
    Color? colorPatch,
    bool dashed = false,
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

    List<Widget> hoverPartImageLine(
      String name, {
      String? image,
      Color? colorPatch,
      bool dashed = false,
      double leftEdge = 5.0,
    }) {
      String displayName = name;
      // Empty string overflows, default value space.
      String displayValue = ' ';
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

      Widget traceColor;
      if (colorPatch != null) {
        if (dashed) {
          traceColor = createDashWidget(colorPatch);
        } else {
          traceColor = createSolidLine(colorPatch);
        }
      } else {
        traceColor = image == null
            ? const SizedBox()
            : scaleImage
                ? Image(
                    image: AssetImage(image),
                    width: 20,
                    height: 10,
                  )
                : Image(
                    image: AssetImage(image),
                  );
      }

      return [
        traceColor,
        const PaddedDivider(
          padding: EdgeInsets.only(left: denseRowSpacing),
        ),
        Text(displayName, style: bold ? hoverTitleEntry : hoverSmallEntry),
        Text(displayValue, style: hoverValueEntry),
      ];
    }

    final rowChildren = <Widget>[];

    rowChildren.addAll(
      hoverPartImageLine(
        name,
        image: image,
        colorPatch: colorPatch,
        dashed: dashed,
        leftEdge: leftPadding,
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 2),
      child: Row(
        children: rowChildren,
      ),
    );
  }

  List<Widget> displayExtensionEventsInHover(ChartsValues chartsValues) {
    final widgets = <Widget>[];

    final eventsDisplayed = chartsValues.extensionEventsToDisplay;

    for (var entry in eventsDisplayed.entries) {
      if (entry.key.endsWith(eventsDisplayName)) {
        widgets.add(
          Container(
            height: hoverEventsHeight,
            child: ListView(
              shrinkWrap: true,
              primary: false,
              children: [
                listItem(
                  allEvents: chartsValues.extensionEvents,
                  title: entry.key,
                  icon: Icons.dashboard,
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(hoverRow(name: entry.key, image: entry.value));

        /// Pull out the event name, and custom values.
        final output =
            displayEvent(null, chartsValues.extensionEvents.first).trim();
        widgets.add(hoverRow(name: output, bold: false, leftPadding: 0.0));
      }
    }
    return widgets;
  }

  List<Widget> displayEventsInHover(ChartsValues chartsValues) {
    final results = <Widget>[];

    final colorScheme = Theme.of(context).colorScheme;
    final eventsDisplayed = chartsValues.eventsToDisplay(colorScheme.isLight);

    for (var entry in eventsDisplayed.entries) {
      final widget = hoverRow(name: ' ${entry.key}', image: entry.value);
      results.add(widget);
    }

    return results;
  }

  /// Long string need to show first part ... last part.
  static const longStringLength = 34;
  static const firstCharacters = 9;
  static const lastCharacters = 20;

  // TODO(terry): Data could be long need better mechanism for long data e.g.,:
  //                const encoder = JsonEncoder.withIndent('  ');
  //                final displayData = encoder.convert(data);
  String longValueToShort(String longValue) {
    var value = longValue;
    if (longValue.length > longStringLength) {
      final firstPart = longValue.substring(0, firstCharacters);
      final endPart = longValue.substring(longValue.length - lastCharacters);
      value = '$firstPart...$endPart';
    }
    return value;
  }

  String decodeEventValues(Map<String, Object> event) {
    final output = StringBuffer();
    if (event[eventName] == imageSizesForFrameEvent) {
      // TODO(terry): Need a more generic event displayer.
      // Flutter event emit the event name and value.
      final data = (event[eventData] as Map).cast<String, Object>();
      final key = data.keys.first;
      output.writeln('${longValueToShort(key)}');
      final values = data[key] as Map<dynamic, dynamic>;
      final displaySize = values[displaySizeInBytesData];
      final decodeSize = values[decodedSizeInBytesData];
      final outputSizes = '$displaySize/$decodeSize';
      if (outputSizes.length > 10) {
        output.writeln('Display/Decode Size=');
        output.write('    $outputSizes');
      } else {
        output.write('Display/Decode Size=$outputSizes');
      }
    } else if (event[eventName] == devToolsEvent &&
        event.containsKey(customEvent)) {
      final custom = event[customEvent] as Map<dynamic, dynamic>;
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

  String displayEvent(int? index, Map<String, Object> event) {
    final output = StringBuffer();

    String? name;

    if (event[eventName] == devToolsEvent && event.containsKey(customEvent)) {
      final custom = event[customEvent] as Map<dynamic, dynamic>;
      name = custom[customEventName];
    } else {
      name = event[eventName] as String?;
    }

    output.writeln(index == null ? name : '$index. $name');
    output.write(decodeEventValues(event));

    return output.toString();
  }

  Widget listItem({
    required List<Map<String, Object>> allEvents,
    int? index,
    required String title,
    IconData? icon,
  }) {
    final widgets = <Widget>[];
    var index = 1;
    for (var event in allEvents) {
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
              image: allEvents.length > 1
                  ? const AssetImage(events.eventsLegend)
                  : const AssetImage(events.eventLegend),
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

  List<Widget> _dataToDisplay(
    Map<String, Map<String, Object?>> dataToDisplay, {
    Widget? firstWidget,
  }) {
    final results = <Widget>[];

    if (firstWidget != null) results.add(firstWidget);

    for (var entry in dataToDisplay.entries) {
      final image = entry.value.keys.contains(renderImage)
          ? entry.value[renderImage] as String?
          : null;
      final color = entry.value.keys.contains(renderLine)
          ? entry.value[renderLine] as Color?
          : null;
      final dashedLine = entry.value.keys.contains(renderDashed)
          ? entry.value[renderDashed]
          : false;

      results.add(
        hoverRow(
          name: entry.key,
          colorPatch: color,
          dashed: dashedLine == true,
          image: image,
          hasNumeric: true,
          hasUnit: memoryController.unitDisplayed.value,
          scaleImage: true,
        ),
      );
    }

    return results;
  }

  List<Widget> displayVmDataInHover(ChartsValues chartsValues) =>
      _dataToDisplay(
        chartsValues.displayVmDataToDisplay(_chartControllers.vm.traces),
      );

  List<Widget> displayAndroidDataInHover(ChartsValues chartsValues) {
    const dividerLineVerticalSpace = 2.0;
    const dividerLineHorizontalSpace = 20.0;
    const totalDividerLineHorizontalSpace = dividerLineHorizontalSpace * 2;

    if (!memoryController.isAndroidChartVisibleNotifier.value) return [];

    final androidDataDisplayed =
        chartsValues.androidDataToDisplay(_chartControllers.android.traces);

    // Separator between Android data.
    // TODO(terry): Why Center widget doesn't work (parent width is bigger/centered too far right).
    //              Is it centering on a too wide Overlay?
    final width = MemoryBodyState.hoverWidth -
        totalDividerLineHorizontalSpace -
        DashedLine.defaultDashWidth;
    final dashedColor = Colors.grey.shade600;

    return _dataToDisplay(
      androidDataDisplayed,
      firstWidget: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: dividerLineVerticalSpace,
            horizontal: dividerLineHorizontalSpace,
          ),
          child: CustomPaint(painter: DashedLine(width, dashedColor)),
        ),
      ),
    );
  }

  void showHover(
    BuildContext context,
    ChartsValues chartsValues,
    Offset position,
  ) {
    final focusColor = Theme.of(context).focusColor;
    final colorScheme = Theme.of(context).colorScheme;

    final box = hoverKey.currentContext!.findRenderObject() as RenderBox;
    final renderBoxWidth = box.size.width;

    // Display hover to left of right side of position.
    double xPosition = position.dx + hoverXOffset;
    if (xPosition + hoverWidth > renderBoxWidth) {
      xPosition = position.dx - hoverWidth - hoverXOffset;
    }

    double totalHoverHeight;
    int totalTraces;
    if (memoryController.isAndroidChartVisibleNotifier.value) {
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

    final OverlayState overlayState = Overlay.of(context)!;
    _hoverOverlayEntry ??= OverlayEntry(
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

    overlayState.insert(_hoverOverlayEntry!);
  }

  void hideHover() {
    if (_hoverOverlayEntry != null) {
      _chartControllers.event.tapLocation.value = null;
      _chartControllers.vm.tapLocation.value = null;
      _chartControllers.android.tapLocation.value = null;

      _hoverOverlayEntry?.remove();
      _hoverOverlayEntry = null;
    }
  }
}
