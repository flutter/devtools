// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

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

class TimelineScreenBodyState extends State<TimelineScreenBody> {
  TimelineController controller;

  StreamSubscription selectedFrameSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = Controllers.of(context).timeline;
    controller.timelineService.updateListeningState(true);

    // TODO(kenz): use Notifier class to register and unregister listeners.
    // TODO(terry): Add AutoDisposeMixin and remove selectedFrameSubscription.
    selectedFrameSubscription?.cancel();
    selectedFrameSubscription =
        controller.frameBasedTimeline.onSelectedFrame.listen((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // TODO(kenz): make TimelineController disposable via
    // DisposableController and dispose here.
    controller.timelineService.updateListeningState(false);
    selectedFrameSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: _buildTimelineStateButtons(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildSecondaryButtons(),
            ),
          ],
        ),
        if (controller.timelineMode == TimelineMode.frameBased)
          const FlutterFramesChart(),
        if (controller.timelineMode == TimelineMode.full ||
            controller.frameBasedTimeline.data?.selectedFrame != null)
          Expanded(
            child: Split(
              axis: Axis.vertical,
              firstChild: TimelineFlameChart(),
              // TODO(kenz): use StreamBuilder to get selected event from
              // controller once data is hooked up.
              secondChild: EventDetails(stubAsyncEvent),
              initialFirstFraction: 0.6,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTimelineStateButtons() {
    return [
      if (controller.timelineMode == TimelineMode.frameBased) ...[
        OutlineButton(
          onPressed: _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed: _resumeLiveTimeline,
          child: const MaterialIconLabel(
            Icons.play_arrow,
            'Resume',
            minIncludeTextWidth: 900,
          ),
        ),
      ],
      if (controller.timelineMode == TimelineMode.full) ...[
        OutlineButton(
          onPressed: _startRecording,
          child: const MaterialIconLabel(
            Icons.fiber_manual_record,
            'Record',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed: _stopRecording,
          child: const MaterialIconLabel(
            Icons.stop,
            'Stop',
            minIncludeTextWidth: 900,
          ),
        ),
      ],
      const SizedBox(width: 8.0),
      OutlineButton(
        onPressed: _clearTimeline,
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
              value: controller.timelineMode == TimelineMode.frameBased,
              onChanged: _onTimelineModeChanged,
            ),
            const Text('Show frames'),
          ],
        ),
      ),
    ];
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

  void _pauseLiveTimeline() {
    // TODO(kenz): implement.
  }

  void _resumeLiveTimeline() {
    // TODO(kenz): implement.
  }

  void _startRecording() {
    // TODO(kenz): implement.
  }

  void _stopRecording() {
    // TODO(kenz): implement.
  }

  void _clearTimeline() {
    // TODO(kenz): implement.
  }

  void _exportTimeline() {
    // TODO(kenz): implement.
  }

  void _onTimelineModeChanged(bool frameBased) {
    setState(() {
      controller.timelineMode =
          frameBased ? TimelineMode.frameBased : TimelineMode.full;
    });
  }
}
