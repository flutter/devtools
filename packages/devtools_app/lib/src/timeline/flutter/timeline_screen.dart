// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/banner_messages.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/notifications.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../service_extensions.dart';
import '../../ui/flutter/label.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../../ui/flutter/vm_flag_widgets.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'timeline_controller.dart';
import 'timeline_flame_chart.dart';
import 'timeline_model.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class TimelineScreen extends Screen {
  const TimelineScreen() : super(id, title: 'Timeline', icon: Octicons.pulse);

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const flameChartSectionKey = Key('Flame Chart Section');
  @visibleForTesting
  static const emptyTimelineRecordingKey = Key('Empty Timeline Recording');
  @visibleForTesting
  static const recordButtonKey = Key('Record Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');
  @visibleForTesting
  static const recordingStatusKey = Key('Recording Status');
  @visibleForTesting
  static const stopRecordingButtonKey = Key('Stop Recording Button');

  static const id = 'timeline';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return offlineMode || !serviceManager.connectedApp.isDartWebAppNow
        ? const TimelineScreenBody()
        : const DisabledForWebAppMessage();
  }
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
  static const _primaryControlsMinIncludeTextWidth = 825.0;
  static const _secondaryControlsMinIncludeTextWidth = 1205.0;

  TimelineController controller;

  bool recording = false;

  bool processing = false;

  double processingProgress = 0.0;

  TimelineEvent selectedEvent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, TimelineScreen.id);

    final newController = Provider.of<TimelineController>(context);
    if (newController == controller) return;
    controller = newController;

    controller.timelineService.updateListeningState(true);

    cancel();
    addAutoDisposeListener(controller.recording, () {
      setState(() {
        recording = controller.recording.value;
      });
    });
    addAutoDisposeListener(controller.processing, () {
      setState(() {
        processing = controller.processing.value;
      });
    });
    addAutoDisposeListener(controller.processor.progressNotifier, () {
      setState(() {
        processingProgress = controller.processor.progressNotifier.value;
      });
    });
    addAutoDisposeListener(controller.selectedFrame);
    addAutoDisposeListener(controller.selectedTimelineEvent, () {
      setState(() {
        selectedEvent = controller.selectedTimelineEvent.value;
      });
    });

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
  void dispose() {
    controller.timelineService.updateListeningState(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOfflineFlutterApp = offlineMode &&
        controller.offlineTimelineData != null &&
        controller.offlineTimelineData.frames.isNotEmpty;

    final timelineScreen = Column(
      children: [
        if (!offlineMode) _timelineControls(),
        const SizedBox(height: denseRowSpacing),
        if (isOfflineFlutterApp ||
            (!offlineMode && serviceManager.connectedApp.isFlutterAppNow))
          const FlutterFramesChart(),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            initialFractions: const [0.6, 0.4],
            children: [
              _buildFlameChartSection(selectedEvent),
              EventDetails(selectedEvent),
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
            color: Colors.grey[50],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _timelineControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPrimaryStateControls(),
        _buildSecondaryControls(),
      ],
    );
  }

  Widget _buildPrimaryStateControls() {
    return Row(
      children: [
        recordButton(
          key: TimelineScreen.recordButtonKey,
          recording: recording,
          minIncludeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: _startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: TimelineScreen.stopRecordingButtonKey,
          recording: recording,
          minIncludeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: _stopRecording,
        ),
        const SizedBox(width: defaultSpacing),
        clearButton(
          key: TimelineScreen.clearButtonKey,
          minIncludeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: () async {
            await _clearTimeline();
          },
        ),
      ],
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
        _logNetworkTrafficButton(),
        const SizedBox(width: defaultSpacing),
        Container(
          height: Theme.of(context).buttonTheme.height,
          child: OutlineButton(
            onPressed: _exportTimeline,
            child: const MaterialIconLabel(
              Icons.file_download,
              'Export',
              minIncludeTextWidth: _secondaryControlsMinIncludeTextWidth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _logNetworkTrafficButton() {
    return ValueListenableBuilder(
      valueListenable: controller.httpTimelineLoggingEnabled,
      builder: (context, enabled, _) {
        return ToggleButtons(
          constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
          children: [
            ToggleButton(
              icon: Icons.language,
              text: 'Network',
              enabledTooltip: 'Stop logging network traffic',
              disabledTooltip: 'Log network traffic',
              minIncludeTextWidth: _secondaryControlsMinIncludeTextWidth,
              selected: enabled,
            ),
          ],
          isSelected: [enabled],
          onPressed: (_) => controller.toggleHttpRequestLogging(!enabled),
        );
      },
    );
  }

  Widget _buildFlameChartSection(TimelineEvent selectedEvent) {
    Widget content;
    final timelineEmpty = (controller.data?.isEmpty ?? true) ||
        controller.data.eventGroups.isEmpty;
    if (recording || processing || timelineEmpty) {
      content = ValueListenableBuilder<bool>(
        valueListenable: controller.emptyRecording,
        builder: (context, emptyRecording, _) {
          return emptyRecording
              ? const Center(
                  key: TimelineScreen.emptyTimelineRecordingKey,
                  child: Text('No timeline events recorded'),
                )
              : _buildRecordingInfo();
        },
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return TimelineFlameChart(
            controller.data,
            width: constraints.maxWidth,
            selected: selectedEvent,
            onSelection: (e) => controller.selectTimelineEvent(e),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        key: TimelineScreen.flameChartSectionKey,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).focusColor),
        ),
        child: content,
      ),
    );
  }

  Widget _buildRecordingInfo() {
    return recordingInfo(
      instructionsKey: TimelineScreen.recordingInstructionsKey,
      recordingStatusKey: TimelineScreen.recordingStatusKey,
      recording: recording,
      processing: processing,
      progressValue: processingProgress,
      recordedObject: 'timeline trace',
    );
  }

  Future<void> _startRecording() async {
    await _clearTimeline();
    await controller.startRecording();
  }

  Future<void> _stopRecording() async {
    await controller.stopRecording();
  }

  Future<void> _clearTimeline() async {
    await controller.clearData();
    setState(() {});
  }

  void _exportTimeline() {
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    Notifications.of(context)
        .push('Successfully exported $exportedFile to ~/Downloads directory');
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
