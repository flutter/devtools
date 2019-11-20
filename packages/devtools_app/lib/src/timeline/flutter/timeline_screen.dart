// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
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

class TimelineScreen extends Screen {
  const TimelineScreen() : super('Timeline');

  static const clearButtonKey = Key('Clear Button');
  static const emptyTimelineRecordingKey = Key('Empty Timeline Recording');
  static const flameChartSectionKey = Key('Flame Chart Section');
  static const recordButtonKey = Key('Record Button');
  static const recordingInstructionsKey = Key('Recording Instructions');
  static const recordingStatusKey = Key('Recording Status');
  static const stopRecordingButtonKey = Key('Stop Recording Button');

  @override
  Widget build(BuildContext context) => TimelineScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Octicons.getIconData('pulse')),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = Controllers.of(context).timeline;
    controller.timelineService.updateListeningState(true);
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
    return ValueListenableBuilder(
      valueListenable: controller.timelineModeNotifier,
      builder: (context, mode, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimelineStateButtons(mode),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildSecondaryButtons(),
                ),
              ],
            ),
            if (mode == TimelineMode.frameBased) const FlutterFramesChart(),
            ValueListenableBuilder(
              valueListenable:
                  controller.frameBasedTimeline.selectedFrameNotifier,
              builder: (context, selectedFrame, _) {
                return (mode == TimelineMode.full || selectedFrame != null)
                    ? Expanded(
                        child: Split(
                          axis: Axis.vertical,
                          firstChild: _buildFlameChartSection(mode),
                          secondChild: ValueListenableBuilder(
                            valueListenable:
                                controller.selectedTimelineEventNotifier,
                            builder: (context, selectedEvent, _) {
                              return EventDetails(selectedEvent);
                            },
                          ),
                          initialFirstFraction: 0.6,
                        ),
                      )
                    : const SizedBox();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineStateButtons(TimelineMode mode) {
    final sharedWidgets = [
      const SizedBox(width: 8.0),
      OutlineButton(
        key: TimelineScreen.clearButtonKey,
        onPressed: () async {
          await _clearTimeline();
        },
        child: const MaterialIconLabel(
          Icons.block,
          'Clear',
          minIncludeTextWidth: 900,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Switch(
              value: mode == TimelineMode.frameBased,
              onChanged: _onTimelineModeChanged,
            ),
            const Text('Show frames'),
          ],
        ),
      ),
    ];
    if (mode == TimelineMode.frameBased) {
      return ValueListenableBuilder(
        valueListenable: controller.frameBasedTimeline.pausedNotifier,
        builder: (context, paused, _) {
          return Row(
            children: [
              OutlineButton(
                onPressed: paused ? null : _pauseLiveTimeline,
                child: const MaterialIconLabel(
                  Icons.pause,
                  'Pause',
                  minIncludeTextWidth: 900,
                ),
              ),
              OutlineButton(
                onPressed: !paused ? null : _resumeLiveTimeline,
                child: const MaterialIconLabel(
                  Icons.play_arrow,
                  'Resume',
                  minIncludeTextWidth: 900,
                ),
              ),
              ...sharedWidgets,
            ],
          );
        },
      );
    } else {
      return ValueListenableBuilder(
        valueListenable: controller.fullTimeline.recordingNotifier,
        builder: (context, recording, _) {
          return Row(
            children: [
              OutlineButton(
                key: TimelineScreen.recordButtonKey,
                onPressed: recording ? null : _startRecording,
                child: const MaterialIconLabel(
                  Icons.fiber_manual_record,
                  'Record',
                  minIncludeTextWidth: 900,
                ),
              ),
              OutlineButton(
                key: TimelineScreen.stopRecordingButtonKey,
                onPressed: !recording ? null : _stopRecording,
                child: const MaterialIconLabel(
                  Icons.stop,
                  'Stop',
                  minIncludeTextWidth: 900,
                ),
              ),
              ...sharedWidgets,
            ],
          );
        },
      );
    }
  }

  List<Widget> _buildSecondaryButtons() {
    return [
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
    ];
  }

  Widget _buildFlameChartSection(TimelineMode mode) {
    Widget content;
    final fullTimelineEmpty = controller.fullTimeline.data?.isEmpty ?? true;
    if (mode == TimelineMode.full && fullTimelineEmpty) {
      content = ValueListenableBuilder(
        valueListenable: controller.fullTimeline.emptyRecordingNotifier,
        builder: (context, emptyRecording, _) {
          if (emptyRecording)
            return const Center(
              key: TimelineScreen.emptyTimelineRecordingKey,
              child: Text('No timeline events recorded'),
            );
          else {
            final recordingInstructions = Column(
              key: TimelineScreen.recordingInstructionsKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Click the record button '),
                    Icon(Icons.fiber_manual_record),
                    Text(' to start recording timeline trace.')
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Click the stop button '),
                    Icon(Icons.stop),
                    Text(' to end the recording.')
                  ],
                ),
              ],
            );
            final recordingStatus = Column(
              key: TimelineScreen.recordingStatusKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Recording timeline trace'),
                SizedBox(height: 16.0),
                CircularProgressIndicator(),
              ],
            );
            return ValueListenableBuilder(
              valueListenable: controller.fullTimeline.recordingNotifier,
              builder: (context, recording, _) {
                return Center(
                  child: recording ? recordingStatus : recordingInstructions,
                );
              },
            );
          }
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
  }

  void _exportTimeline() {
    // TODO(kenz): implement.
  }

  // TODO(kenz): consider making timeline mode a ValueNotifier on the controller
  void _onTimelineModeChanged(bool frameBased) async {
    await _clearTimeline();
    controller.timelineModeNotifier.value =
        frameBased ? TimelineMode.frameBased : TimelineMode.full;
  }
}
