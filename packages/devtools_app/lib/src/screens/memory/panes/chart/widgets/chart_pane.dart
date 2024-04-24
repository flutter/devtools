// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/charts/chart_controller.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/ui/colors.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/primitives/painting.dart';
import '../controller/chart_pane_controller.dart';
import '../data/charts.dart';
import 'chart_control_pane.dart';
import 'legend.dart';
import 'memory_android_chart.dart';
import 'memory_events_pane.dart';
import 'memory_vm_chart.dart';

class MemoryChartPane extends StatefulWidget {
  const MemoryChartPane({
    Key? key,
    required this.chart,
    required this.keyFocusNode,
  }) : super(key: key);
  final MemoryChartPaneController chart;

  /// Which widget's key press will be handled by chart.
  final FocusNode keyFocusNode;

  static final hoverKey = GlobalKey(debugLabel: 'Chart Hover');

  @override
  State<MemoryChartPane> createState() => _MemoryChartPaneState();
}

class _MemoryChartPaneState extends State<MemoryChartPane>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  OverlayEntry? _hoverOverlayEntry;

  static const _hoverXOffset = 10;
  static const _hoverYOffset = 0.0;

  static double get _hoverWidth => scaleByFontFactor(225.0);
  static const _hoverCardBorderWidth = 2.0;

  // TODO(terry): Compute below heights dynamically.
  static double get _hoverHeightMinimum => scaleByFontFactor(42.0);
  static double get hoverItemHeight => scaleByFontFactor(17.0);

  /// One extension event to display (4 lines).
  static double get _hoverOneEventsHeight => scaleByFontFactor(82.0);

  /// Many extension events to display.
  static double get _hoverEventsHeight => scaleByFontFactor(120.0);

  static double _computeHoverHeight(
    int eventsCount,
    int tracesCount,
    int extensionEventsCount,
  ) =>
      _hoverHeightMinimum +
      (eventsCount * hoverItemHeight) +
      _hoverCardBorderWidth +
      (tracesCount * hoverItemHeight) +
      (extensionEventsCount > 0
          ? (extensionEventsCount == 1
              ? _hoverOneEventsHeight
              : _hoverEventsHeight)
          : 0);

  static int get _timestamp => DateTime.now().millisecondsSinceEpoch;

  void _addTapLocationListener(
    ValueNotifier<TapLocation?> tapLocation,
    List<ValueNotifier<TapLocation?>> allLocations,
  ) {
    addAutoDisposeListener(tapLocation, () {
      final value = tapLocation.value;
      if (value == null) return;

      if (_hoverOverlayEntry != null) {
        _hideHover();
        return;
      }

      final details = value.tapDownDetails;
      if (details == null) return;

      final copied = TapLocation.copy(value);
      for (var location in allLocations) {
        if (location != tapLocation) location.value = copied;
      }

      final allValues = ChartsValues(
        widget.chart.data.timeline,
        isAndroidChartVisible: widget.chart.isAndroidChartVisible,
        index: value.index,
        timestamp: value.timestamp ?? _timestamp,
      );

      _showHover(
        context,
        allValues,
        details.globalPosition,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant MemoryChartPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart == widget.chart) return;
    _init();
  }

  void _init() {
    final allLocations = [
      widget.chart.event.tapLocation,
      widget.chart.vm.tapLocation,
      widget.chart.android.tapLocation,
    ];

    for (var location in allLocations) {
      _addTapLocationListener(location, allLocations);
    }

    // There is no listener passed, so SetState will be invoked.
    addAutoDisposeListener(
      widget.chart.isAndroidChartVisible,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('!!!! build MemoryChartPane');
    const memoryEventsPainHeight = 70.0;
    return ValueListenableBuilder<bool>(
      valueListenable: preferences.memory.showChart,
      builder: (_, showChart, __) {
        if (!showChart) return const SizedBox.shrink();

        return KeyboardListener(
          focusNode: widget.keyFocusNode,
          onKeyEvent: (KeyEvent event) {
            if (event.isKeyDownOrRepeat &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              _hideHover();
            }
          },
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The chart.
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: memoryEventsPainHeight,
                      child: MemoryEventsPane(widget.chart.event),
                    ),
                    MemoryVMChart(widget.chart.vm),
                    if (widget.chart.isAndroidChartVisible.value)
                      SizedBox(
                        height: defaultChartHeight,
                        child: MemoryAndroidChart(
                          widget.chart.android,
                          widget.chart.data.timeline,
                        ),
                      ),
                  ],
                ),
              ),
              // The legend.
              MultiValueListenableBuilder(
                listenables: [
                  widget.chart.data.isLegendVisible,
                  widget.chart.isAndroidChartVisible,
                ],
                builder: (_, values, __) {
                  final isLegendVisible = values.first as bool;
                  final isAndroidChartVisible = values.second as bool;
                  if (!isLegendVisible) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: denseSpacing,
                      bottom: denseSpacing,
                    ),
                    child: MemoryChartLegend(
                      isAndroidVisible: isAndroidChartVisible,
                      chartController: widget.chart,
                    ),
                  );
                },
              ),
              // Chart control pane.
              ChartControlPane(
                chart: widget.chart,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideHover();
    super.dispose();
  }

  List<Widget> _displayVmDataInHover(ChartsValues chartsValues) =>
      _dataToDisplay(
        chartsValues.displayVmDataToDisplay(widget.chart.vm.traces),
      );

  List<Widget> _displayAndroidDataInHover(ChartsValues chartsValues) {
    const dividerLineVerticalSpace = 2.0;
    const dividerLineHorizontalSpace = 20.0;
    const totalDividerLineHorizontalSpace = dividerLineHorizontalSpace * 2;

    if (!widget.chart.isAndroidChartVisible.value) {
      return [];
    }

    final androidDataDisplayed =
        chartsValues.androidDataToDisplay(widget.chart.android.traces);

    // Separator between Android data.
    // TODO(terry): Why Center widget doesn't work (parent width is bigger/centered too far right).
    //              Is it centering on a too wide Overlay?
    final width = _hoverWidth -
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

  void _showHover(
    BuildContext context,
    ChartsValues chartsValues,
    Offset position,
  ) {
    final theme = Theme.of(context);
    final focusColor = theme.focusColor;
    final colorScheme = theme.colorScheme;

    final box = MemoryChartPane.hoverKey.currentContext!.findRenderObject()
        as RenderBox;
    final renderBoxWidth = box.size.width;

    // Display hover to left of right side of position.
    double xPosition = position.dx + _hoverXOffset;
    if (xPosition + _hoverWidth > renderBoxWidth) {
      xPosition = position.dx - _hoverWidth - _hoverXOffset;
    }

    double totalHoverHeight;
    int totalTraces;
    totalTraces = widget.chart.isAndroidChartVisible.value
        ? chartsValues.vmData.entries.length -
            1 +
            chartsValues.androidData.entries.length
        : chartsValues.vmData.entries.length - 1;

    totalHoverHeight = _computeHoverHeight(
      chartsValues.eventCount,
      totalTraces,
      chartsValues.extensionEventsLength,
    );

    final displayTimestamp = prettyTimestamp(chartsValues.timestamp);

    final OverlayState overlayState = Overlay.of(context);
    _hoverOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + _hoverYOffset,
        left: xPosition,
        height: totalHoverHeight,
        child: Container(
          padding: const EdgeInsets.only(top: 5, bottom: 8),
          decoration: BoxDecoration(
            color: colorScheme.defaultBackgroundColor,
            border: Border.all(
              color: focusColor,
              width: _hoverCardBorderWidth,
            ),
            borderRadius: defaultBorderRadius,
          ),
          width: _hoverWidth,
          child: ListView(
            children: [
              Container(
                width: _hoverWidth,
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Time $displayTimestamp',
                  style: theme.legendTextStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              ..._displayEventsInHover(chartsValues),
              ..._displayVmDataInHover(chartsValues),
              ..._displayAndroidDataInHover(chartsValues),
              ..._displayExtensionEventsInHover(chartsValues),
            ],
          ),
        ),
      ),
    );

    overlayState.insert(_hoverOverlayEntry!);
  }

  List<Widget> _dataToDisplay(
    Map<String, Map<String, Object?>> dataToDisplay, {
    Widget? firstWidget,
  }) {
    final results = <Widget>[];

    if (firstWidget != null) results.add(firstWidget);

    for (var entry in dataToDisplay.entries) {
      final keys = entry.value.keys;
      final image = keys.contains(renderImage)
          ? entry.value[renderImage] as String?
          : null;
      final color =
          keys.contains(renderLine) ? entry.value[renderLine] as Color? : null;
      final dashedLine =
          keys.contains(renderDashed) ? entry.value[renderDashed] : false;

      results.add(
        _hoverRow(
          name: entry.key,
          colorPatch: color,
          dashed: dashedLine == true,
          image: image,
          hasNumeric: true,
          scaleImage: true,
        ),
      );
    }

    return results;
  }

  Widget _hoverRow({
    required String name,
    String? image,
    Color? colorPatch,
    bool dashed = false,
    bool hasNumeric = false,
    bool scaleImage = false,
  }) {
    final theme = Theme.of(context);
    List<Widget> hoverPartImageLine(
      String name, {
      String? image,
      Color? colorPatch,
      bool dashed = false,
    }) {
      String displayName = name;
      // Empty string overflows, default value space.
      String displayValue = ' ';
      if (hasNumeric) {
        int startOfNumber = name.lastIndexOf(' ');

        final unitOrValue = name.substring(startOfNumber + 1);
        if (int.tryParse(unitOrValue) == null) {
          // Got a unit.
          startOfNumber = name.lastIndexOf(' ', startOfNumber - 1);
        }

        displayName = '${name.substring(0, startOfNumber)} ';
        displayValue = name.substring(startOfNumber + 1);
      }

      Widget traceColor;
      // Logic would be hard to read as a conditional expression.
      // ignore: prefer-conditional-expression
      if (colorPatch != null) {
        traceColor =
            dashed ? createDashWidget(colorPatch) : createSolidLine(colorPatch);
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
        Text(displayName, style: theme.legendTextStyle),
        Text(displayValue, style: theme.legendTextStyle),
      ];
    }

    final rowChildren = <Widget>[];

    rowChildren.addAll(
      hoverPartImageLine(
        name,
        image: image,
        colorPatch: colorPatch,
        dashed: dashed,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(left: 5, bottom: 2),
      child: Row(
        children: rowChildren,
      ),
    );
  }

  void _hideHover() {
    if (_hoverOverlayEntry != null) {
      widget.chart.event.tapLocation.value = null;
      widget.chart.vm.tapLocation.value = null;
      widget.chart.android.tapLocation.value = null;

      _hoverOverlayEntry?.remove();
      _hoverOverlayEntry = null;
    }
  }

  List<Widget> _displayExtensionEventsInHover(ChartsValues chartsValues) {
    return [
      if (chartsValues.hasExtensionEvents)
        ..._extensionEvents(
          allEvents: chartsValues.extensionEvents,
        ),
    ];
  }

  List<Widget> _displayEventsInHover(ChartsValues chartsValues) {
    final results = <Widget>[];

    final colorScheme = Theme.of(context).colorScheme;
    final eventsDisplayed = chartsValues.eventsToDisplay(colorScheme.isLight);

    for (var entry in eventsDisplayed.entries) {
      final widget = _hoverRow(name: ' ${entry.key}', image: entry.value);
      results.add(widget);
    }

    return results;
  }

  List<Widget> _extensionEvents({
    required List<Map<String, Object>> allEvents,
  }) {
    final theme = Theme.of(context);

    final widgets = <Widget>[];
    var index = 1;
    for (var event in allEvents) {
      late String? name;
      if (event[eventName] == devToolsEvent && event.containsKey(customEvent)) {
        final custom = event[customEvent] as Map<dynamic, dynamic>;
        name = custom[customEventName];
      } else {
        name = event[eventName] as String?;
      }

      final output = _decodeEventValues(event);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: intermediateSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$index. $name',
                overflow: TextOverflow.ellipsis,
                style: theme.legendTextStyle,
              ),
              Padding(
                padding: const EdgeInsets.only(left: densePadding),
                child: Text(
                  output,
                  overflow: TextOverflow.ellipsis,
                  style: theme.legendTextStyle,
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    }

    final eventsLength = allEvents.length;
    final title = Row(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 6.0),
          child: Image(
            image: AssetImage(eventLegendAsset(eventsLength)),
          ),
        ),
        const SizedBox(width: denseSpacing),
        Text(
          '$eventsLength ${pluralize('Event', eventsLength)}',
          style: theme.legendTextStyle,
        ),
      ],
    );
    return [
      title,
      ...widgets,
    ];
  }

  String _decodeEventValues(Map<String, Object> event) {
    final output = StringBuffer();
    if (event[eventName] == imageSizesForFrameEvent) {
      // TODO(terry): Need a more generic way to display event.
      // Flutter event emit the event name and value.
      final data = (event[eventData] as Map).cast<String, Object>();
      final key = data.keys.first;
      output.writeln(_longValueToShort(key));
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
      final custom = event[customEvent] as Map<Object?, Object?>;
      final data = custom[customEventData] as Map<Object?, Object?>;
      for (var key in data.keys) {
        output.write('$key=');
        output.writeln(_longValueToShort(data[key] as String));
      }
    } else {
      output.writeln('Unknown Event ${event[eventName]}');
    }

    return output.toString();
  }

  /// Long string need to show first part ... last part.
  static const _longStringLength = 34;
  static const _firstCharacters = 9;
  static const _lastCharacters = 20;

  // TODO(terry): Data could be long need better mechanism for long data e.g.,:
  //                const encoder = JsonEncoder.withIndent('  ');
  //                final displayData = encoder.convert(data);
  String _longValueToShort(String longValue) {
    var value = longValue;
    if (longValue.length > _longStringLength) {
      final firstPart = longValue.substring(0, _firstCharacters);
      final endPart = longValue.substring(longValue.length - _lastCharacters);
      value = '$firstPart...$endPart';
    }
    return value;
  }
}
