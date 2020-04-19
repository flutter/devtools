// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config_specific/flutter/import_export/import_export.dart';
import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/banner_messages.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
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
  const TimelineScreen()
      : super(
          DevToolsScreenType.timeline,
          title: 'Timeline',
          icon: Octicons.pulse,
        );

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

  @override
  String get docPageId => 'timeline';

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isDartWebAppNow
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
    with AutoDisposeMixin {
  static const _primaryControlsMinIncludeTextWidth = 825.0;
  static const _secondaryControlsMinIncludeTextWidth = 1205.0;

  TimelineController controller;

  final _exportController = ExportController();

  bool recording = false;
  bool processing = false;
  double processingProgress = 0.0;
  TimelineEvent selectedEvent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, DevToolsScreenType.timeline);

    final newController = Controllers.of(context).timeline;
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
  }

  @override
  void dispose() {
    controller.timelineService.updateListeningState(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _timelineControls(),
        const SizedBox(height: denseRowSpacing),
        if (serviceManager.connectedApp.isFlutterAppNow)
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
  }

  Widget _timelineControls() {
    final _exitOfflineButton = exitOfflineButton(() {
      setState(() {
        controller.exitOfflineMode();
      });
    });
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: offlineMode
          ? [_exitOfflineButton]
          : [
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
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: _startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: TimelineScreen.stopRecordingButtonKey,
          recording: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: _stopRecording,
        ),
        const SizedBox(width: defaultSpacing),
        clearButton(
          key: TimelineScreen.clearButtonKey,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
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
        const ProfileGranularityDropdown(DevToolsScreenType.timeline),
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
              includeTextWidth: _secondaryControlsMinIncludeTextWidth,
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
              includeTextWidth: _secondaryControlsMinIncludeTextWidth,
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
    final exportedFile = _exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    Notifications.of(context)
        .push('Successfully exported $exportedFile to ~/Downloads directory');
  }

  // TODO(kenz): move this to the controller once the dart:html app is deleted.
  // This code relies on `import_export.dart` which contains a flutter import.
  /// Exports the current timeline data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String _exportData() {
    // TODO(kenz): add analytics for this. It would be helpful to know how
    // complex the problems are that users are trying to solve.
    final encodedTimelineData = jsonEncode(controller.data.json);
    final now = DateTime.now();
    final timestamp =
        '${now.year}_${now.month}_${now.day}-${now.microsecondsSinceEpoch}';
    final fileName = 'timeline_$timestamp.json';
    _exportController.downloadFile(fileName, encodedTimelineData);
    return fileName;
  }
}
