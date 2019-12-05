// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../service_extensions.dart';
import '../../ui/flutter/label.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../../ui/flutter/vm_flag_widgets.dart';
import '../timeline_controller.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'timeline_flame_chart.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class TimelineScreen extends Screen {
  const TimelineScreen() : super();

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const flameChartSectionKey = Key('Flame Chart Section');
  @visibleForTesting
  static const pauseButtonKey = Key('Pause Button');
  @visibleForTesting
  static const resumeButtonKey = Key('Resume Button');
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
  Widget build(BuildContext context) => TimelineScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Timeline',
      icon: Icon(Octicons.pulse),
    );
  }
}

class TimelineScreenBody extends StatefulWidget {
  @override
  TimelineScreenBodyState createState() => TimelineScreenBodyState();
}

class TimelineScreenBodyState extends State<TimelineScreenBody>
    with AutoDisposeMixin {
  TimelineController controller;

  TimelineMode get timelineMode => controller.timelineModeNotifier.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Controllers.of(context).timeline;
    if (newController == controller) return;
    controller = newController;

    controller.timelineService.updateListeningState(true);

    cancel();
    addAutoDisposeListener(controller.timelineModeNotifier);
    autoDispose(controller.fullTimeline.onTimelineProcessed.listen((_) {
      setState(() {});
    }));
  }

  @override
  void dispose() {
    // TODO(kenz): make TimelineController disposable via
    // DisposableController and dispose here.
    controller.timelineService.updateListeningState(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPrimaryStateControls(),
            _buildSecondaryControls(),
          ],
        ),
        if (timelineMode == TimelineMode.frameBased) const FlutterFramesChart(),
        ValueListenableBuilder(
          valueListenable: controller.frameBasedTimeline.selectedFrameNotifier,
          builder: (context, selectedFrame, _) {
            return (timelineMode == TimelineMode.full || selectedFrame != null)
                ? Expanded(
                    child: Split(
                      axis: Axis.vertical,
                      firstChild: _buildFlameChartSection(),
                      secondChild: _buildEventDetailsSection(),
                      initialFirstFraction: 0.6,
                    ),
                  )
                : const SizedBox();
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryStateControls() {
    const double minIncludeTextWidth = 900;
    final sharedWidgets = [
      const SizedBox(width: 8.0),
      clearButton(
        key: TimelineScreen.clearButtonKey,
        minIncludeTextWidth: minIncludeTextWidth,
        onPressed: () async {
          await _clearTimeline();
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Switch(
              value: timelineMode == TimelineMode.frameBased,
              onChanged: _onTimelineModeChanged,
            ),
            const Text('Show frames'),
          ],
        ),
      ),
    ];
    return timelineMode == TimelineMode.frameBased
        ? _buildFrameBasedTimelineButtons(sharedWidgets, minIncludeTextWidth)
        : _buildFullTimelineButtons(sharedWidgets, minIncludeTextWidth);
  }

  Widget _buildFrameBasedTimelineButtons(
    List<Widget> sharedWidgets,
    double minIncludeTextWidth,
  ) {
    return ValueListenableBuilder(
      valueListenable: controller.frameBasedTimeline.pausedNotifier,
      builder: (context, paused, _) {
        return Row(
          children: [
            OutlineButton(
              key: TimelineScreen.pauseButtonKey,
              onPressed: paused ? null : _pauseLiveTimeline,
              child: MaterialIconLabel(
                Icons.pause,
                'Pause',
                minIncludeTextWidth: minIncludeTextWidth,
              ),
            ),
            OutlineButton(
              key: TimelineScreen.resumeButtonKey,
              onPressed: !paused ? null : _resumeLiveTimeline,
              child: MaterialIconLabel(
                Icons.play_arrow,
                'Resume',
                minIncludeTextWidth: minIncludeTextWidth,
              ),
            ),
            ...sharedWidgets,
          ],
        );
      },
    );
  }

  Widget _buildFullTimelineButtons(
    List<Widget> sharedWidgets,
    double minIncludeTextWidth,
  ) {
    return ValueListenableBuilder(
      valueListenable: controller.fullTimeline.recordingNotifier,
      builder: (context, recording, _) {
        return Row(
          children: [
            recordButton(
              key: TimelineScreen.recordButtonKey,
              recording: recording,
              minIncludeTextWidth: minIncludeTextWidth,
              onPressed: _startRecording,
            ),
            stopRecordingButton(
              key: TimelineScreen.stopRecordingButtonKey,
              recording: recording,
              minIncludeTextWidth: minIncludeTextWidth,
              onPressed: _stopRecording,
            ),
            ...sharedWidgets,
          ],
        );
      },
    );
  }

  Widget _buildSecondaryControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ProfileGranularityDropdown(),
        ),
        ServiceExtensionButtonGroup(
          minIncludeTextWidth: 1100,
          extensions: [performanceOverlay],
        ),
        const SizedBox(width: 8.0),
        OutlineButton(
          onPressed: _exportTimeline,
          child: MaterialIconLabel(
            Icons.file_download,
            'Export',
            minIncludeTextWidth: 1100,
          ),
        ),
      ],
    );
  }

  Widget _buildFlameChartSection() {
    Widget content;
    final fullTimelineEmpty = controller.fullTimeline.data?.isEmpty ?? true;
    if (timelineMode == TimelineMode.full && fullTimelineEmpty) {
      content = ValueListenableBuilder(
        valueListenable: controller.fullTimeline.emptyRecordingNotifier,
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
      content = TimelineFlameChart();
    }

    return Container(
      key: TimelineScreen.flameChartSectionKey,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
      ),
      child: content,
    );
  }

  Widget _buildRecordingInfo() {
    return ValueListenableBuilder(
      valueListenable: controller.fullTimeline.recordingNotifier,
      builder: (context, recording, _) {
        return recordingInfo(
          instructionsKey: TimelineScreen.recordingInstructionsKey,
          statusKey: TimelineScreen.recordingStatusKey,
          recording: recording,
          recordedObject: 'timeline trace',
        );
      },
    );
  }

  Widget _buildEventDetailsSection() {
    return ValueListenableBuilder(
      valueListenable: controller.selectedTimelineEventNotifier,
      builder: (context, selectedEvent, _) {
        return EventDetails(selectedEvent);
      },
    );
  }

  void _pauseLiveTimeline() {
    setState(() {
      controller.frameBasedTimeline.pause(manual: true);
      controller.timelineService.updateListeningState(true);
    });
  }

  void _resumeLiveTimeline() {
    setState(() {
      controller.frameBasedTimeline.resume();
      controller.timelineService.updateListeningState(true);
    });
  }

  void _startRecording() async {
    await _clearTimeline();
    controller.fullTimeline.startRecording();
  }

  void _stopRecording() {
    controller.fullTimeline.stopRecording();
  }

  Future<void> _clearTimeline() async {
    await controller.clearData();
    setState(() {});
  }

  void _exportTimeline() {
    // TODO(kenz): implement.
  }

  void _onTimelineModeChanged(bool frameBased) async {
    await _clearTimeline();
    controller.selectTimelineMode(
        frameBased ? TimelineMode.frameBased : TimelineMode.full);
  }
}
