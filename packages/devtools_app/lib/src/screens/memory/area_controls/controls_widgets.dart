import 'package:flutter/material.dart';

import '../../../shared/common_widgets.dart';
import '../memory_controller.dart';

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
import 'constants.dart';
import 'memory_config.dart';

class ChartControls extends StatefulWidget {
  const ChartControls({
    Key? key,
    required this.chartControllers,
  }) : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<ChartControls> createState() => _ChartControlsState();
}

class _ChartControlsState extends State<ChartControls>
    with MemoryControllerMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  void _onPause() {
    ga.select(analytics_constants.memory, analytics_constants.pause);
    memoryController.pauseLiveFeed();
  }

  void _onResume() {
    ga.select(analytics_constants.memory, analytics_constants.resume);
    memoryController.resumeLiveFeed();
  }

  void _clearTimeline() {
    ga.select(analytics_constants.memory, analytics_constants.clear);

    memoryController.memoryTimeline.reset();

    // Clear any current Allocation Profile collected.
    memoryController.monitorAllocations = [];
    memoryController.monitorTimestamp = null;
    memoryController.lastMonitorTimestamp.value = null;
    memoryController.trackAllocations.clear();
    memoryController.allocationSamples.clear();

    // Clear all analysis and snapshots collected too.
    memoryController.clearAllSnapshots();
    memoryController.classRoot = null;
    memoryController.topNode = null;
    memoryController.selectedSnapshotTimestamp = null;
    memoryController.selectedLeaf = null;

    // Remove history of all plotted data in all charts.
    widget.chartControllers.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: memoryController.paused,
      builder: (context, paused, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PauseButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? null : _onPause,
            ),
            const SizedBox(width: denseSpacing),
            ResumeButton(
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
              onPressed: paused ? _onResume : null,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              // TODO(terry): Button needs to be Delete for offline data.
              onPressed:
                  memoryController.memorySource == MemoryController.liveFeed
                      ? _clearTimeline
                      : null,
              minScreenWidthForTextBeforeScaling:
                  primaryControlsMinVerboseWidth,
            ),
            const SizedBox(width: defaultSpacing),
            IntervalDropdown(chartControllers: widget.chartControllers),
          ],
        );
      },
    );
  }
}

class IntervalDropdown extends StatefulWidget {
  const IntervalDropdown({Key? key, required this.chartControllers})
      : super(key: key);

  final ChartControllers chartControllers;

  @override
  State<IntervalDropdown> createState() => _IntervalDropdownState();
}

class _IntervalDropdownState extends State<IntervalDropdown>
    with MemoryControllerMixin<IntervalDropdown> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
      value: displayDuration(memoryController.displayInterval),
      onChanged: (String? newValue) {
        setState(() {
          ga.select(
            analytics_constants.memory,
            '${analytics_constants.memoryDisplayInterval}-$newValue',
          );
          memoryController.displayInterval = chartInterval(newValue!);
          final duration = chartDuration(memoryController.displayInterval);

          widget.chartControllers.event.zoomDuration = duration;
          widget.chartControllers.vm.zoomDuration = duration;
          widget.chartControllers.android.zoomDuration = duration;
        });
      },
      items: _displayTypes,
    );
  }
}

class SourceDropdownMenuItem<T> extends DropdownMenuItem<T> {
  const SourceDropdownMenuItem({T? value, required Widget child})
      : super(value: value, child: child);
}

class MemorySourceDropdown extends StatefulWidget {
  const MemorySourceDropdown({Key? key}) : super(key: key);

  @override
  State<MemorySourceDropdown> createState() => _MemorySourceDropdownState();
}

class _MemorySourceDropdownState extends State<MemorySourceDropdown>
    with MemoryControllerMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final files = memoryController.memoryLog.offlineFiles();

    // Can we display dropdowns in verbose mode?
    final isVerbose =
        memoryController.memorySourcePrefix == memorySourceMenuItemPrefix;

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
          '${memoryController.memorySourcePrefix}$displayValue',
          key: sourcesKey,
        ),
      );
    }).toList();

    return RoundedDropDownButton<String>(
      key: sourcesDropdownKey,
      isDense: true,
      style: textTheme.bodyText2,
      value: memoryController.memorySource,
      onChanged: (String? newValue) {
        setState(() {
          ga.select(
            analytics_constants.memory,
            analytics_constants.sourcesDropDown,
          );
          memoryController.memorySource = newValue!;
        });
      },
      items: allMemorySources,
    );
  }
}

class CreateToggleAdbMemoryButton extends StatefulWidget {
  const CreateToggleAdbMemoryButton(
      {Key? key, required this.isAndroidCollection})
      : super(key: key);
  final bool isAndroidCollection;

  @override
  State<CreateToggleAdbMemoryButton> createState() =>
      _CreateToggleAdbMemoryButtonState();
}

class _CreateToggleAdbMemoryButtonState
    extends State<CreateToggleAdbMemoryButton> with MemoryControllerMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      icon: memoryController.isAndroidChartVisible
          ? Icons.close
          : Icons.show_chart,
      label: 'Android Memory',
      onPressed: widget.isAndroidCollection
          ? memoryController.toggleAndroidChartVisibility
          : null,
      minScreenWidthForTextBeforeScaling: 900,
    );
  }
}

/// Controls related to the entire memory screen.
class CommonControls extends StatefulWidget {
  const CommonControls(
      {Key? key,
      required this.isAndroidCollection,
      required this.isAdvancedSettingsEnabled})
      : super(key: key);

  final bool isAndroidCollection;
  final bool isAdvancedSettingsEnabled;

  @override
  State<CommonControls> createState() => _CommonControlsState();
}

class _CommonControlsState extends State<CommonControls>
    with MemoryControllerMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    initMemoryController();
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    memoryController.memorySourcePrefix =
        mediaWidth > verboseDropDownMinimumWidth
            ? memorySourceMenuItemPrefix
            : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MemorySourceDropdown(),
        const SizedBox(width: defaultSpacing),
        if (memoryController.isConnectedDeviceAndroid ||
            memoryController.isOfflineAndAndroidData)
          CreateToggleAdbMemoryButton(
              isAndroidCollection: widget.isAndroidCollection),
        const SizedBox(width: denseSpacing),
        widget.isAdvancedSettingsEnabled
            ? Row(
                children: [
                  IconLabelButton(
                    onPressed: memoryController.isGcing ? null : _gc,
                    icon: Icons.delete,
                    label: 'GC',
                    minScreenWidthForTextBeforeScaling:
                        primaryControlsMinVerboseWidth,
                  ),
                  const SizedBox(width: denseSpacing),
                ],
              )
            : const SizedBox(),
        ExportButton(
          onPressed: memoryController.offline.value ? null : _exportToFile,
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          key: legendKey,
          onPressed: memoryController.toggleLegendVisibility,
          icon: _legendOverlayEntry == null ? Icons.storage : Icons.close,
          label: 'Legend',
          tooltip: 'Legend',
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
          label: 'Memory Configuration',
        ),
      ],
    );
  }

  Future<void> _gc() async {
    try {
      ga.select(analytics_constants.memory, analytics_constants.gc);

      memoryController.memoryTimeline.addGCEvent();

      await memoryController.gc();
    } catch (e) {
      // TODO(terry): Show toast?
      log('Unable to GC ${e.toString()}', LogLevel.error);
    }
  }
}
