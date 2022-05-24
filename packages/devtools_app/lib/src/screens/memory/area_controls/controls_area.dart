// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../analytics/analytics.dart' as ga;
import '../../../analytics/constants.dart' as analytics_constants;
import '../../../config_specific/logger/logger.dart';
import '../../../primitives/auto_dispose_mixin.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/notifications.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils.dart';
import '../memory_android_chart.dart' as android;
import '../memory_charts.dart';
import '../memory_controller.dart';
import '../memory_events_pane.dart' as events;
import '../memory_vm_chart.dart' as vm;
import '../primitives/painting.dart';
import 'memory_config.dart';

/// Width of application when memory buttons loose their text.
const _primaryControlsMinVerboseWidth = 1100.0;

/// When to have verbose Dropdown based on media width.
const _verboseDropDownMinimumWidth = 950;

const _memorySourceMenuItemPrefix = 'Source: ';

final _legendKey = GlobalKey(debugLabel: 'Legend Button');
const legendXOffset = 20;
const legendYOffset = 7.0;
double get legendWidth => scaleByFontFactor(200.0);
double get legendTextWidth => scaleByFontFactor(55.0);
double get legendHeight1Chart => scaleByFontFactor(200.0);
double get legendHeight2Charts => scaleByFontFactor(323.0);

// TODO(kenz): clean up these keys. We should remove them if we are only using
// for testing and can avoid them.

@visibleForTesting
const sourcesDropdownKey = Key('Sources Dropdown');

@visibleForTesting
const sourcesKey = Key('Sources');

class ControlsArea extends StatefulWidget {
  const ControlsArea({Key? key}) : super(key: key);

  @override
  State<ControlsArea> createState() => _ControlsAreaState();
}

class _ControlsAreaState extends State<ControlsArea> with AutoDisposeMixin {
  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;
  bool _controllersInitialized = false;
  bool _isAdvancedSettingsEnabled = false;

  OverlayEntry? _legendOverlayEntry;

  late MemoryController _controller;
  late events.EventChartController _eventChartController;
  late vm.VMChartController _vmChartController;
  late android.AndroidChartController _androidChartController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPrimaryStateControls(textTheme),
        const Spacer(),
        _buildMemoryControls(textTheme),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (!_controllersInitialized || newController != _controller) {
      _controllersInitialized = true;
      _controller = newController;
      _eventChartController = events.EventChartController(_controller);
      _vmChartController = vm.VMChartController(_controller);
      // Android Chart uses the VM Chart's computed labels.
      _androidChartController = android.AndroidChartController(
        _controller,
        sharedLabels: _vmChartController.labelTimestamps,
      );
    }

    setupTraces(isDarkMode: themeData.isDarkTheme);

    addAutoDisposeListener(_controller.androidCollectionEnabled, () {
      _isAndroidCollection = _controller.androidCollectionEnabled.value;
      setState(() {
        if (!_isAndroidCollection && _controller.isAndroidChartVisible) {
          // If we're no longer collecting android stats then hide the
          // chart and disable the Android Memory button.
          _controller.toggleAndroidChartVisibility();
        }
      });
    });

    addAutoDisposeListener(_controller.advancedSettingsEnabled, () {
      _isAdvancedSettingsEnabled = _controller.advancedSettingsEnabled.value;
      setState(() {
        if (!_isAdvancedSettingsEnabled &&
            _controller.isAdvancedSettingsVisible) {
          _controller.toggleAdvancedSettingsVisibility();
        }
      });
    });

    addAutoDisposeListener(_controller.legendVisibleNotifier, () {
      setState(() {
        if (_controller.isLegendVisible) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.memoryLegend,
          );

          _showLegend(context);
        } else {
          _hideLegend();
        }
      });
    });

    addAutoDisposeListener(_controller.androidChartVisibleNotifier, () {
      setState(() {
        if (_controller.androidChartVisibleNotifier.value) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.androidChart,
          );
        }
        if (_controller.isLegendVisible) {
          // Recompute the legend with the new traces now visible.
          _hideLegend();
          _showLegend(context);
        }
      });
    });
  }

  Widget _buildPrimaryStateControls(TextTheme textTheme) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.paused,
      builder: (context, paused, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PauseButton(
              minScreenWidthForTextBeforeScaling:
                  _primaryControlsMinVerboseWidth,
              onPressed: paused ? null : _onPause,
            ),
            const SizedBox(width: denseSpacing),
            ResumeButton(
              minScreenWidthForTextBeforeScaling:
                  _primaryControlsMinVerboseWidth,
              onPressed: paused ? _onResume : null,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              // TODO(terry): Button needs to be Delete for offline data.
              onPressed: _controller.memorySource == MemoryController.liveFeed
                  ? _clearTimeline
                  : null,
              minScreenWidthForTextBeforeScaling:
                  _primaryControlsMinVerboseWidth,
            ),
            const SizedBox(width: defaultSpacing),
            _intervalDropdown(textTheme),
          ],
        );
      },
    );
  }

  void _onPause() {
    ga.select(analytics_constants.memory, analytics_constants.pause);
    _controller.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(analytics_constants.memory, analytics_constants.resume);
    _controller.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(analytics_constants.memory, analytics_constants.clear);

    _controller.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    _controller.monitorAllocations = [];
    _controller.monitorTimestamp = null;
    _controller.lastMonitorTimestamp.value = null;
    _controller.trackAllocations.clear();
    _controller.allocationSamples.clear();

    // Clear all analysis and snapshots collected too.
    _controller.clearAllSnapshots();
    _controller.classRoot = null;
    _controller.topNode = null;
    _controller.selectedSnapshotTimestamp = null;
    _controller.selectedLeaf = null;

    // Remove history of all plotted data in all charts.
    _eventChartController.reset();
    _vmChartController.reset();
    _androidChartController.reset();
  }

  void _exportToFile() {
    final outputPath = _controller.memoryLog.exportMemory();
    final notificationsState = Notifications.of(context);
    if (notificationsState != null) {
      notificationsState.push(
        'Successfully exported file ${outputPath.last} to ${outputPath.first} directory',
      );
    }
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MemoryConfigurationsDialog(_controller),
    );
  }

  Widget _intervalDropdown(TextTheme textTheme) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerboseDropdown = mediaWidth > _verboseDropDownMinimumWidth;

    final displayOneMinute =
        chartDuration(ChartInterval.OneMinute)!.inMinutes.toString();

    final _displayTypes = displayDurationsStrings.map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        final unit = value == displayDefault || value == displayAll
            ? ''
            : 'Minute${value == displayOneMinute ? '' : 's'}';

        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            '${isVerboseDropdown ? 'Display' : ''} $value $unit',
          ),
        );
      },
    ).toList();

    return RoundedDropDownButton<String>(
      isDense: true,
      style: textTheme.bodyText2,
      value: displayDuration(_controller.displayInterval),
      onChanged: (String? newValue) {
        setState(() {
          ga.select(
            analytics_constants.memory,
            '${analytics_constants.memoryDisplayInterval}-$newValue',
          );
          _controller.displayInterval = chartInterval(newValue!);
          final duration = chartDuration(_controller.displayInterval);

          _eventChartController.zoomDuration = duration;
          _vmChartController.zoomDuration = duration;
          _androidChartController.zoomDuration = duration;
        });
      },
      items: _displayTypes,
    );
  }

  Widget _memorySourceDropdown(TextTheme textTheme) {
    final files = _controller.memoryLog.offlineFiles();

    // Can we display dropdowns in verbose mode?
    final isVerbose =
        _controller.memorySourcePrefix == _memorySourceMenuItemPrefix;

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
      return SourceDropdownMenuItem<String>(
        value: value,
        child: Text(
          '${_controller.memorySourcePrefix}$displayValue',
          key: sourcesKey,
        ),
      );
    }).toList();

    return RoundedDropDownButton<String>(
      key: sourcesDropdownKey,
      isDense: true,
      style: textTheme.bodyText2,
      value: _controller.memorySource,
      onChanged: (String? newValue) {
        setState(() {
          ga.select(
            analytics_constants.memory,
            analytics_constants.sourcesDropDown,
          );
          _controller.memorySource = newValue!;
        });
      },
      items: allMemorySources,
    );
  }

  Widget _createToggleAdbMemoryButton() {
    return IconLabelButton(
      icon: _controller.isAndroidChartVisible ? Icons.close : Icons.show_chart,
      label: 'Android Memory',
      onPressed: _isAndroidCollection
          ? _controller.toggleAndroidChartVisibility
          : null,
      minScreenWidthForTextBeforeScaling: 900,
    );
  }

  Widget _buildMemoryControls(TextTheme textTheme) {
    final mediaWidth = MediaQuery.of(context).size.width;
    _controller.memorySourcePrefix = mediaWidth > _verboseDropDownMinimumWidth
        ? _memorySourceMenuItemPrefix
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _memorySourceDropdown(textTheme),
        const SizedBox(width: defaultSpacing),
        if (_controller.isConnectedDeviceAndroid ||
            _controller.isOfflineAndAndroidData)
          _createToggleAdbMemoryButton(),
        const SizedBox(width: denseSpacing),
        _isAdvancedSettingsEnabled
            ? Row(
                children: [
                  IconLabelButton(
                    onPressed: _controller.isGcing ? null : _gc,
                    icon: Icons.delete,
                    label: 'GC',
                    minScreenWidthForTextBeforeScaling:
                        _primaryControlsMinVerboseWidth,
                  ),
                  const SizedBox(width: denseSpacing),
                ],
              )
            : const SizedBox(),
        ExportButton(
          onPressed: _controller.offline.value ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          key: _legendKey,
          onPressed: _controller.toggleLegendVisibility,
          icon: _legendOverlayEntry == null ? Icons.storage : Icons.close,
          label: 'Legend',
          tooltip: 'Legend',
          minScreenWidthForTextBeforeScaling: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
          label: 'Memory Configuration',
        ),
      ],
    );
  }

  /// Padding for each title in the legend.
  static const _legendTitlePadding = EdgeInsets.fromLTRB(5, 0, 0, 4);

  void _showLegend(BuildContext context) {
    print('!!!! showing legend');
    final box = _legendKey.currentContext!.findRenderObject() as RenderBox;

    final colorScheme = Theme.of(context).colorScheme;
    final legendHeading = colorScheme.hoverTextStyle;

    // Global position.
    final position = box.localToGlobal(Offset.zero);

    final legendRows = <Widget>[];

    final events = eventLegend(colorScheme.isLight);
    legendRows.add(
      Container(
        padding: _legendTitlePadding,
        child: Text('Events Legend', style: legendHeading),
      ),
    );

    var iterator = events.entries.iterator;
    while (iterator.moveNext()) {
      final leftEntry = iterator.current;
      final rightEntry = iterator.moveNext() ? iterator.current : null;
      legendRows.add(legendRow(entry1: leftEntry, entry2: rightEntry));
    }

    final vms = vmLegend();
    legendRows.add(
      Container(
        padding: _legendTitlePadding,
        child: Text('Memory Legend', style: legendHeading),
      ),
    );

    iterator = vms.entries.iterator;
    while (iterator.moveNext()) {
      final legendEntry = iterator.current;
      legendRows.add(legendRow(entry1: legendEntry));
    }

    if (_controller.isAndroidChartVisible) {
      final androids = androidLegend();
      legendRows.add(
        Container(
          padding: _legendTitlePadding,
          child: Text('Android Legend', style: legendHeading),
        ),
      );

      iterator = androids.entries.iterator;
      while (iterator.moveNext()) {
        final legendEntry = iterator.current;
        legendRows.add(legendRow(entry1: legendEntry));
      }
    }

    final OverlayState overlayState = Overlay.of(context)!;
    _legendOverlayEntry ??= OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + box.size.height + legendYOffset,
        left: position.dx - legendWidth + box.size.width - legendXOffset,
        height: _controller.isAndroidChartVisible
            ? legendHeight2Charts
            : legendHeight1Chart,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 5, 5, 8),
          decoration: BoxDecoration(
            color: colorScheme.defaultBackgroundColor,
            border: Border.all(color: Colors.yellow),
            borderRadius: BorderRadius.circular(10.0),
          ),
          width: legendWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendRows,
          ),
        ),
      ),
    );

    overlayState.insert(_legendOverlayEntry!);
  }

  void _hideLegend() {
    _legendOverlayEntry?.remove();
    _legendOverlayEntry = null;
  }

  Future<void> _gc() async {
    try {
      ga.select(analytics_constants.memory, analytics_constants.gc);

      _controller.memoryTimeline.addGCEvent();

      await _controller.gc();
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }

  Map<String, Map<String, Object?>> eventLegend(bool isLight) {
    final result = <String, Map<String, Object?>>{};

    result[events.manualSnapshotLegendName] = traceRender(
      image: events.snapshotManualLegend,
    );
    result[events.autoSnapshotLegendName] = traceRender(
      image: events.snapshotAutoLegend,
    );
    result[events.monitorLegendName] = traceRender(image: events.monitorLegend);
    result[events.resetLegendName] = traceRender(
      image: isLight ? events.resetLightLegend : events.resetDarkLegend,
    );
    result[events.vmGCLegendName] = traceRender(image: events.gcVMLegend);
    result[events.manualGCLegendName] = traceRender(
      image: events.gcManualLegend,
    );
    result[events.eventLegendName] = traceRender(image: events.eventLegend);
    result[events.eventsLegendName] = traceRender(image: events.eventsLegend);

    return result;
  }

  Map<String, Map<String, Object?>> vmLegend() {
    final result = <String, Map<String, Object?>>{};

    final traces = _vmChartController.traces;
    // RSS trace
    result[rssDisplay] = traceRender(
      color: traces[vm.TraceName.rSS.index].characteristics.color,
      dashed: true,
    );

    // Allocated trace
    result[allocatedDisplay] = traceRender(
      color: traces[vm.TraceName.capacity.index].characteristics.color,
      dashed: true,
    );

    // Used trace
    result[usedDisplay] = traceRender(
      color: traces[vm.TraceName.used.index].characteristics.color,
    );

    // External trace
    result[externalDisplay] = traceRender(
      color: traces[vm.TraceName.external.index].characteristics.color,
    );

    // Raster layer trace
    result[layerDisplay] = traceRender(
      color: traces[vm.TraceName.rasterLayer.index].characteristics.color,
      dashed: true,
    );

    // Raster picture trace
    result[pictureDisplay] = traceRender(
      color: traces[vm.TraceName.rasterPicture.index].characteristics.color,
      dashed: true,
    );

    return result;
  }

  Map<String, Map<String, Object?>> androidLegend() {
    final result = <String, Map<String, Object?>>{};

    final traces = _androidChartController.traces;
    // Total trace
    result[androidTotalDisplay] = traceRender(
      color: traces[android.TraceName.total.index].characteristics.color,
      dashed: true,
    );

    // Other trace
    result[androidOtherDisplay] = traceRender(
      color: traces[android.TraceName.other.index].characteristics.color,
    );

    // Native heap trace
    result[androidNativeDisplay] = traceRender(
      color: traces[android.TraceName.nativeHeap.index].characteristics.color,
    );

    // Graphics trace
    result[androidGraphicsDisplay] = traceRender(
      color: traces[android.TraceName.graphics.index].characteristics.color,
    );

    // Code trace
    result[androidCodeDisplay] = traceRender(
      color: traces[android.TraceName.code.index].characteristics.color,
    );

    // Java heap trace
    result[androidJavaDisplay] = traceRender(
      color: traces[android.TraceName.javaHeap.index].characteristics.color,
    );

    // Stack trace
    result[androidStackDisplay] = traceRender(
      color: traces[android.TraceName.stack.index].characteristics.color,
    );

    return result;
  }

  Widget legendRow({
    required MapEntry<String, Map<String, Object?>> entry1,
    MapEntry<String, Map<String, Object?>>? entry2,
  }) {
    final legendEntry = Theme.of(context).colorScheme.legendTextStyle;

    List<Widget> legendPart(
      String name,
      Widget widget, [
      double leftEdge = 5.0,
    ]) {
      final rightSide = <Widget>[];
      rightSide.addAll([
        Expanded(
          child: Container(
            padding: EdgeInsets.fromLTRB(leftEdge, 0, 0, 2),
            width: legendTextWidth + leftEdge,
            child: Text(name, style: legendEntry),
          ),
        ),
        const PaddedDivider(
          padding: EdgeInsets.only(left: denseRowSpacing),
        ),
        widget,
      ]);

      return rightSide;
    }

    Widget legendSymbol(Map<String, Object?> dataToDisplay) {
      final image = dataToDisplay.containsKey(renderImage)
          ? dataToDisplay[renderImage] as String?
          : null;
      final color = dataToDisplay.containsKey(renderLine)
          ? dataToDisplay[renderLine] as Color?
          : null;
      final dashedLine = dataToDisplay.containsKey(renderDashed)
          ? dataToDisplay[renderDashed]
          : false;

      Widget traceColor;
      if (color != null) {
        if (dashedLine as bool) {
          traceColor = createDashWidget(color);
        } else {
          traceColor = createSolidLine(color);
        }
      } else {
        traceColor =
            image == null ? const SizedBox() : Image(image: AssetImage(image));
      }

      return traceColor;
    }

    final rowChildren = <Widget>[];

    rowChildren.addAll(legendPart(entry1.key, legendSymbol(entry1.value)));
    if (entry2 != null) {
      rowChildren.addAll(
        legendPart(entry2.key, legendSymbol(entry2.value), 20.0),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowChildren,
        ),
      ),
    );
  }
}

class SourceDropdownMenuItem<T> extends DropdownMenuItem<T> {
  const SourceDropdownMenuItem({T? value, required Widget child})
      : super(value: value, child: child);
}
