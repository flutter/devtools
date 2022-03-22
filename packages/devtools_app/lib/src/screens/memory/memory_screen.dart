// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../charts/chart_controller.dart';
import '../../config_specific/logger/logger.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
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

/// Width of application when memory buttons loose their text.
const _primaryControlsMinVerboseWidth = 1100.0;

final legendKey = GlobalKey(debugLabel: 'Legend Button');

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

  // TODO(kenz): clean up these keys. We should remove them if we are only using
  // for testing and can avoid them.

  @visibleForTesting
  static const sourcesDropdownKey = Key('Sources Dropdown');

  @visibleForTesting
  static const sourcesKey = Key('Sources');

  static const memorySourceMenuItemPrefix = 'Source: ';

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
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  late events.EventChartController _eventChartController;
  late vm.VMChartController _vmChartController;
  late android.AndroidChartController _androidChartController;

  late MemoryController _controller;

  bool _controllersInitialized = false;

  OverlayEntry? _hoverOverlayEntry;
  OverlayEntry? _legendOverlayEntry;

  bool _isAdvancedSettingsEnabled = false;

  /// Updated when the MemoryController's _androidCollectionEnabled ValueNotifier changes.
  bool _isAndroidCollection = MemoryController.androidADBDefault;

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

    final newController = Provider.of<MemoryController>(context);
    if (_controllersInitialized && newController == _controller) return;
    _controllersInitialized = true;

    _controller = newController;

    _eventChartController = events.EventChartController(_controller);
    _vmChartController = vm.VMChartController(_controller);
    // Android Chart uses the VM Chart's computed labels.
    _androidChartController = android.AndroidChartController(
      _controller,
      sharedLabels: _vmChartController.labelTimestamps,
    );

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(_controller.selectedSnapshotNotifier, () {
      setState(() {
        // TODO(terry): Create the snapshot data to display by Library,
        //              by Class or by Objects.
        // Create the snapshot data by Library.
        _controller.createSnapshotByLibrary();
      });
    });

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(_controller.memorySourceNotifier, () async {
      try {
        await _controller.updatedMemorySource();
      } catch (e) {
        final errorMessage = '$e';
        _controller.memorySource = MemoryController.liveFeed;
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

      _controller.refreshAllCharts();
    });

    addAutoDisposeListener(_controller.legendVisibleNotifier, () {
      setState(() {
        if (_controller.isLegendVisible) {
          ga.select(
            analytics_constants.memory,
            analytics_constants.memoryLegend,
          );

          showLegend(context);
        } else {
          hideLegend();
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
          hideLegend();
          showLegend(context);
        }
      });
    });

    addAutoDisposeListener(_eventChartController.tapLocation, () {
      if (_eventChartController.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _eventChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _vmChartController.tapLocation.value = copied;
          _androidChartController.tapLocation.value = copied;

          final allValues = ChartsValues(_controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('Event Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

    addAutoDisposeListener(_vmChartController.tapLocation, () {
      if (_vmChartController.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _vmChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _eventChartController.tapLocation.value = copied;
          _androidChartController.tapLocation.value = copied;

          final allValues = ChartsValues(_controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('VM Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

    addAutoDisposeListener(_androidChartController.tapLocation, () {
      if (_androidChartController.tapLocation.value != null) {
        if (_hoverOverlayEntry != null) {
          hideHover();
        }
        final tapLocation = _androidChartController.tapLocation.value;
        if (tapLocation?.tapDownDetails != null) {
          final tapData = tapLocation!;
          final index = tapData.index;
          final timestamp = tapData.timestamp!;

          final copied = TapLocation.copy(tapLocation);
          _eventChartController.tapLocation.value = copied;
          _vmChartController.tapLocation.value = copied;

          final allValues = ChartsValues(_controller, index, timestamp);
          if (MemoryScreen.isDebuggingEnabled) {
            debugLogger('Android Chart TapLocation '
                '${allValues.toJson().prettyPrint()}');
          }
          showHover(context, allValues, tapData.tapDownDetails!.globalPosition);
        }
      }
    });

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

    addAutoDisposeListener(_controller.refreshCharts, () {
      setState(() {
        _refreshCharts();
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

    _controller.memorySourcePrefix = mediaWidth > verboseDropDownMinimumWidth
        ? MemoryScreen.memorySourceMenuItemPrefix
        : '';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPrimaryStateControls(textTheme),
              const Spacer(),
              _buildMemoryControls(textTheme),
            ],
          ),
          const SizedBox(height: denseRowSpacing),
          SizedBox(
            height: scaleByFontFactor(70),
            child: events.MemoryEventsPane(_eventChartController),
          ),
          SizedBox(
            child: vm.MemoryVMChart(_vmChartController),
          ),
          _controller.isAndroidChartVisible
              ? SizedBox(
                  height: defaultChartHeight,
                  child: android.MemoryAndroidChart(_androidChartController),
                )
              : const SizedBox(),
          const SizedBox(width: defaultSpacing),
          Expanded(
            child: HeapTree(_controller),
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
    _eventChartController.reset();
    _vmChartController.reset();
    _androidChartController.reset();

    _recomputeChartData();
  }

  /// Recompute (attach data to the chart) for either live or offline data source.
  void _recomputeChartData() {
    _eventChartController.setupData();
    _eventChartController.dirty = true;
    _vmChartController.setupData();
    _vmChartController.dirty = true;
    _androidChartController.setupData();
    _androidChartController.dirty = true;
  }

  Widget _intervalDropdown(TextTheme textTheme) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isVerboseDropdown = mediaWidth > verboseDropDownMinimumWidth;

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
    final isVerbose = _controller.memorySourcePrefix ==
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
      return SourceDropdownMenuItem<String>(
        value: value,
        child: Text(
          '${_controller.memorySourcePrefix}$displayValue',
          key: MemoryScreen.sourcesKey,
        ),
      );
    }).toList();

    return RoundedDropDownButton<String>(
      key: MemoryScreen.sourcesDropdownKey,
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

  void _updateListeningState() async {
    await serviceManager.onServiceAvailable;

    if (_controller.hasStarted) return;

    await _controller.startTimeline();

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

  Widget createToggleAdbMemoryButton() {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _memorySourceDropdown(textTheme),
        const SizedBox(width: defaultSpacing),
        if (_controller.isConnectedDeviceAndroid ||
            _controller.isOfflineAndAndroidData)
          createToggleAdbMemoryButton(),
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
          onPressed: _controller.offline ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: _primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          key: legendKey,
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

  static const legendXOffset = 20;
  static const legendYOffset = 7.0;
  static double get legendWidth => scaleByFontFactor(200.0);
  static double get legendTextWidth => scaleByFontFactor(55.0);
  static double get legendHeight1Chart => scaleByFontFactor(200.0);
  static double get legendHeight2Charts => scaleByFontFactor(323.0);

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

  static const totalDashWidth = 15.0;
  static const dashHeight = 2.0;
  static const dashWidth = 4.0;
  static const spaceBetweenDash = 3.0;

  Widget createDashWidget(Color color) {
    return Container(
      padding: const EdgeInsets.only(right: 20),
      child: CustomPaint(
        painter: DashedLine(
          totalDashWidth,
          color,
          dashHeight,
          dashWidth,
          spaceBetweenDash,
        ),
        foregroundPainter: DashedLine(
          totalDashWidth,
          color,
          dashHeight,
          dashWidth,
          spaceBetweenDash,
        ),
      ),
    );
  }

  Widget createSolidLine(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: Container(
        height: 6,
        width: 20,
        color: color,
      ),
    );
  }

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

    rowChildren.addAll(hoverPartImageLine(
      name,
      image: image,
      colorPatch: colorPatch,
      dashed: dashed,
      leftEdge: leftPadding,
    ));
    return Container(
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 2),
        child: Row(
          children: rowChildren,
        ));
  }

  List<Widget> displayExtensionEventsInHover(ChartsValues chartsValues) {
    final widgets = <Widget>[];

    final eventsDisplayed = chartsValues.extensionEventsToDisplay;

    for (var entry in eventsDisplayed.entries) {
      if (entry.key.endsWith(eventsDisplayName)) {
        widgets.add(Container(
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
        ));
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
      final data = event[eventData] as Map<String, Object>;
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
          hasUnit: _controller.unitDisplayed.value,
          scaleImage: true,
        ),
      );
    }

    return results;
  }

  List<Widget> displayVmDataInHover(ChartsValues chartsValues) =>
      _dataToDisplay(
        chartsValues.displayVmDataToDisplay(_vmChartController.traces),
      );

  List<Widget> displayAndroidDataInHover(ChartsValues chartsValues) {
    const dividerLineVerticalSpace = 2.0;
    const dividerLineHorizontalSpace = 20.0;
    const totalDividerLineHorizontalSpace = dividerLineHorizontalSpace * 2;

    if (!_controller.isAndroidChartVisible) return [];

    final androidDataDisplayed =
        chartsValues.androidDataToDisplay(_androidChartController.traces);

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
            child: CustomPaint(painter: DashedLine(width, dashedColor))),
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
    if (_controller.isAndroidChartVisible) {
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
      _eventChartController.tapLocation.value = null;
      _vmChartController.tapLocation.value = null;
      _androidChartController.tapLocation.value = null;

      _hoverOverlayEntry?.remove();
      _hoverOverlayEntry = null;
    }
  }

  /// Padding for each title in the legend.
  static const _legendTitlePadding = EdgeInsets.fromLTRB(5, 0, 0, 4);

  void showLegend(BuildContext context) {
    final box = legendKey.currentContext!.findRenderObject() as RenderBox;

    final colorScheme = Theme.of(context).colorScheme;
    final legendHeading = colorScheme.hoverTextStyle;

    // Global position.
    final position = box.localToGlobal(Offset.zero);

    final legendRows = <Widget>[];

    final events = eventLegend(colorScheme.isLight);
    legendRows.add(Container(
      padding: _legendTitlePadding,
      child: Text('Events Legend', style: legendHeading),
    ));

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

  void hideLegend() {
    _legendOverlayEntry?.remove();
    _legendOverlayEntry = null;
  }

  /// Callbacks for button actions:

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
}

/// Draw a dashed line on the canvas.
class DashedLine extends CustomPainter {
  DashedLine(
    this._totalWidth, [
    Color? color,
    this._dashHeight = defaultDashHeight,
    this._dashWidth = defaultDashWidth,
    this._dashSpace = defaultDashSpace,
  ]) {
    _color = color == null ? (Colors.grey.shade500) : color;
  }

  static const defaultDashHeight = 1.0;
  static const defaultDashWidth = 5.0;
  static const defaultDashSpace = 5.0;

  final double _dashHeight;
  final double _dashWidth;
  final double _dashSpace;

  double _totalWidth;
  late Color _color;

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = _color
      ..strokeWidth = _dashHeight;

    while (_totalWidth >= 0) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + _dashWidth, 0), paint);
      final space = _dashSpace + _dashWidth;
      startX += space;
      _totalWidth -= space;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
                        notifier: controller.androidCollectionEnabled
                            as ValueNotifier<bool?>),
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
                    NotifierCheckbox(
                        notifier:
                            controller.unitDisplayed as ValueNotifier<bool?>),
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
            const SizedBox(
              height: defaultSpacing,
            ),
            ...dialogSubHeader(theme, 'General'),
            Column(
              children: [
                Row(
                  children: [
                    NotifierCheckbox(
                      notifier: controller.advancedSettingsEnabled
                          as ValueNotifier<bool?>,
                    ),
                    RichText(
                      overflow: TextOverflow.visible,
                      text: TextSpan(
                        text: 'Enable advanced memory settings',
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

class SourceDropdownMenuItem<T> extends DropdownMenuItem<T> {
  const SourceDropdownMenuItem({T? value, required Widget child})
      : super(value: value, child: child);
}
