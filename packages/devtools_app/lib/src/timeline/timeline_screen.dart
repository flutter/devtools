// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/import_export/import_export.dart';
import '../dialogs.dart';
import '../globals.dart';
import '../notifications.dart';
import '../octicons.dart';
import '../screen.dart';
import '../service_extensions.dart';
import '../split.dart';
import '../theme.dart';
import '../ui/service_extension_widgets.dart';
import '../ui/vm_flag_widgets.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'timeline_controller.dart';
import 'timeline_flame_chart.dart';
import 'timeline_model.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class TimelineScreen extends Screen {
  const TimelineScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          title: 'Timeline',
          icon: Octicons.pulse,
        );

  static const id = 'timeline';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const TimelineScreenBody();
}

class TimelineScreenBody extends StatefulWidget {
  const TimelineScreenBody();

  @override
  TimelineScreenBodyState createState() => TimelineScreenBodyState();
}

class TimelineScreenBodyState extends State<TimelineScreenBody>
    with
        AutoDisposeMixin,
        OfflineScreenMixin<TimelineScreenBody, OfflineTimelineData> {
  static const _primaryControlsMinIncludeTextWidth = 725.0;
  static const _secondaryControlsMinIncludeTextWidth = 1100.0;

  TimelineController controller;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    ga.screen(TimelineScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, TimelineScreen.id);

    final newController = Provider.of<TimelineController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

    processing = controller.processing.value;
    addAutoDisposeListener(controller.processing, () {
      setState(() {
        processing = controller.processing.value;
      });
    });

    processingProgress = controller.processor.progressNotifier.value;
    addAutoDisposeListener(controller.processor.progressNotifier, () {
      setState(() {
        processingProgress = controller.processor.progressNotifier.value;
      });
    });

    addAutoDisposeListener(controller.selectedFrame);

    // Refresh data on page load if data is null. On subsequent tab changes,
    // this should not be called.
    if (controller.data == null && !offlineMode) {
      controller.refreshData();
    }

    // Load offline timeline data if available.
    if (shouldLoadOfflineData()) {
      // This is a workaround to guarantee that DevTools exports are compatible
      // with other trace viewers (catapult, perfetto, chrome://tracing), which
      // require a top level field named "traceEvents". See how timeline data is
      // encoded in [ExportController.encode].
      final timelineJson =
          Map<String, dynamic>.from(offlineDataJson[TimelineScreen.id])
            ..addAll({
              TimelineData.traceEventsKey:
                  offlineDataJson[TimelineData.traceEventsKey]
            });
      final offlineTimelineData = OfflineTimelineData.parse(timelineJson);
      if (!offlineTimelineData.isEmpty) {
        loadOfflineData(offlineTimelineData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOfflineFlutterApp = offlineMode &&
        controller.offlineTimelineData != null &&
        controller.offlineTimelineData.frames.isNotEmpty;

    final timelineScreen = Column(
      children: [
        if (!offlineMode) _buildTimelineControls(),
        const SizedBox(height: denseRowSpacing),
        if (isOfflineFlutterApp ||
            (!offlineMode && serviceManager.connectedApp.isFlutterAppNow))
          ValueListenableBuilder(
            valueListenable: controller.flutterFrames,
            builder: (context, frames, _) => ValueListenableBuilder(
              valueListenable: controller.displayRefreshRate,
              builder: (context, displayRefreshRate, _) {
                return FlutterFramesChart(
                  frames,
                  displayRefreshRate,
                );
              },
            ),
          ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            initialFractions: const [0.6, 0.4],
            children: [
              TimelineFlameChartContainer(
                processing: processing,
                processingProgress: processingProgress,
              ),
              ValueListenableBuilder(
                valueListenable: controller.selectedTimelineEvent,
                builder: (context, selectedEvent, _) {
                  return EventDetails(selectedEvent);
                },
              ),
            ],
          ),
        ),
      ],
    );

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        timelineScreen,
        if (loadingOfflineData)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildTimelineControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPrimaryStateControls(),
        _buildSecondaryControls(),
      ],
    );
  }

  Widget _buildPrimaryStateControls() {
    return ValueListenableBuilder(
      valueListenable: controller.refreshing,
      builder: (context, refreshing, _) {
        return Row(
          children: [
            RefreshButton(
              includeTextWidth: _primaryControlsMinIncludeTextWidth,
              onPressed: (refreshing || processing) ? null : _refreshTimeline,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              includeTextWidth: _primaryControlsMinIncludeTextWidth,
              onPressed: (refreshing || processing) ? null : _clearTimeline,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const ProfileGranularityDropdown(TimelineScreen.id),
        const SizedBox(width: defaultSpacing),
        if (!serviceManager.connectedApp.isDartCliAppNow)
          ServiceExtensionButtonGroup(
            minIncludeTextWidth: _secondaryControlsMinIncludeTextWidth,
            extensions: [performanceOverlay, profileWidgetBuilds],
          ),
        // TODO(kenz): hide or disable button if http timeline logging is not
        // available.
        const SizedBox(width: defaultSpacing),
        ExportButton(
          onPressed: _exportTimeline,
          includeTextWidth: _secondaryControlsMinIncludeTextWidth,
        ),
        const SizedBox(width: defaultSpacing),
        ActionButton(
          child: OutlineButton(
            child: const Icon(
              Icons.tune,
              size: defaultIconSize,
            ),
            onPressed: _openSettingsDialog,
          ),
          tooltip: 'Timeline Configuration',
        ),
      ],
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => TimelineConfigurationsDialog(controller),
    );
  }

  Future<void> _refreshTimeline() async {
    await controller.refreshData();
  }

  Future<void> _clearTimeline() async {
    await controller.clearData();
    setState(() {});
  }

  void _exportTimeline() {
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    // TODO(peterdjlee): find a way to push the notification logic into the
    // export controller.
    Notifications.of(context).push(successfulExportMessage(exportedFile));
  }

  @override
  FutureOr<void> processOfflineData(OfflineTimelineData offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[TimelineScreen.id] != null &&
        offlineDataJson[TimelineData.traceEventsKey] != null;
  }
}

class TimelineConfigurationsDialog extends StatelessWidget {
  const TimelineConfigurationsDialog(this.controller);

  static const dialogWidth = 700.0;

  final TimelineController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Recorded Streams'),
      content: Container(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._defaultRecordedStreams(theme),
            const SizedBox(height: denseSpacing),
            ...dialogSubHeader(theme, 'Advanced'),
            ..._advancedStreams(theme),
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  List<Widget> _defaultRecordedStreams(ThemeData theme) {
    return [
      ..._timelineStreams(theme, advanced: false),
      // Special case "Network Traffic" because it is not implemented as a
      // Timeline recorded stream in the VM. The user does not need to be aware of
      // the distinction, however.
      _buildStream(
        name: 'Network',
        description: ' • Http traffic',
        listenable: controller.httpTimelineLoggingEnabled,
        onChanged: controller.toggleHttpRequestLogging,
        theme: theme,
      ),
    ];
  }

  List<Widget> _advancedStreams(ThemeData theme) {
    return _timelineStreams(theme, advanced: true);
  }

  List<Widget> _timelineStreams(
    ThemeData theme, {
    @required bool advanced,
  }) {
    final settings = <Widget>[];
    final streams = controller.recordedStreams
        .where((s) => s.advanced == advanced)
        .toList();
    for (final stream in streams) {
      settings.add(_buildStream(
        name: stream.name,
        description: ' • ${stream.description}',
        listenable: stream.enabled,
        onChanged: (_) => controller.toggleTimelineStream(stream),
        theme: theme,
      ));
    }
    return settings;
  }

  Widget _buildStream({
    @required String name,
    @required String description,
    @required ValueListenable listenable,
    @required void Function(bool) onChanged,
    @required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder(
          valueListenable: listenable,
          builder: (context, value, _) {
            return Checkbox(
              value: value,
              onChanged: onChanged,
            );
          },
        ),
        Flexible(
          child: RichText(
            overflow: TextOverflow.visible,
            text: TextSpan(
              text: name,
              style: theme.regularTextStyle,
              children: [
                TextSpan(
                  text: description,
                  style: theme.subtleTextStyle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
