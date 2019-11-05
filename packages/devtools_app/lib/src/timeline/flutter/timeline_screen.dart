// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';
import '../../service_extensions.dart';
import '../../ui/flutter/label.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../../ui/flutter/vm_flag_widgets.dart';
import '../../ui/icons.dart';
import '../timeline_controller.dart';

class TimelineScreen extends Screen {
  const TimelineScreen() : super('Timeline');

  @override
  Widget build(BuildContext context) => const TimelineBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Octicons.getIconData('pulse')),
    );
  }
}

class TimelineBody extends StatefulWidget {
  const TimelineBody();

  @override
  TimelineBodyState createState() => TimelineBodyState();
}

class TimelineBodyState extends State<TimelineBody> {
  TimelineMode _timelineMode = TimelineMode.frameBased;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_timelineMode == TimelineMode.frameBased)
                  OutlineButton(
                    onPressed: _pauseLiveTimeline,
                    child: const Label(
                      FlutterIcons.pause,
                      'Pause',
                      minIncludeTextWidth: 900,
                    ),
                  ),
                if (_timelineMode == TimelineMode.frameBased)
                  OutlineButton(
                    onPressed: _resumeLiveTimeline,
                    child: const Label(
                      FlutterIcons.resume,
                      'Resume',
                      minIncludeTextWidth: 900,
                    ),
                  ),
                if (_timelineMode == TimelineMode.full)
                  OutlineButton(
                    onPressed: _startRecording,
                    child: const Label(
                      FlutterIcons.record,
                      'Record',
                      minIncludeTextWidth: 900,
                    ),
                  ),
                if (_timelineMode == TimelineMode.full)
                  OutlineButton(
                    onPressed: _stopRecording,
                    child: const Label(
                      FlutterIcons.stop,
                      'Stop',
                      minIncludeTextWidth: 900,
                    ),
                  ),
                const SizedBox(width: 8.0),
                OutlineButton(
                  onPressed: _clearTimeline,
                  child: const Label(
                    FlutterIcons.clear,
                    'Clear',
                    minIncludeTextWidth: 900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Switch(
                        value: _timelineMode == TimelineMode.frameBased,
                        onChanged: _onTimelineModeChanged,
                      ),
                      const Text('Show frames'),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  child: const Label(
                    FlutterIcons.export,
                    'Export',
                    minIncludeTextWidth: 1100,
                  ),
                ),
              ],
            )
          ],
        ),
        if (_timelineMode == TimelineMode.frameBased) FlutterFramesChart(),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            firstChild: TimelineFlameChart(),
            secondChild: EventDetails(),
            initialFirstFraction: 0.8,
          ),
        ),
      ],
    );
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
      _timelineMode = frameBased ? TimelineMode.frameBased : TimelineMode.full;
    });
  }
}
