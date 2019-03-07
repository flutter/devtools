// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:html' as html;
import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/split.dart' as split;
import '../ui/ui_utils.dart';
import '../vm_service_wrapper.dart';
import 'event_details.dart';
import 'frame_flame_chart.dart';
import 'frames_bar_chart.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

// TODO(terry): These colors need to be ThemedColor.
// Blue 300 from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const Color mainCpuColor = Color(0xFF64B5F6);
// Teal 300 from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const Color mainGpuColor = Color(0xFF4DB6AC);

// Red 300
const Color gpuJankColor = Color(0xFFE57373);
// Red 800
const Color cpuJankColor = Color(0xFFC62828);
// Red 500
const Color hoverJankColor = Color(0xFFF44336);

const Color slowFrameColor = Color(0xFFE50C0C);
const Color selectedColor = Color(0xFF4078C0);

// Blue A700
const Color selectedGpuColor = Color(0xFF2962FF);
// Dark Blue
const Color selectedCpuColor = Color(0xFF09007E);

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-drawn during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): Have a timeline view thumbnail overview.

// TODO(devoncarew): Switch to showing all timeline events, but highlighting the
// area associated with the selected frame.

class TimelineScreen extends Screen {
  TimelineScreen()
      : super(name: 'Timeline', id: 'timeline', iconClass: 'octicon-pulse');

  TimelineController timelineController = TimelineController();

  FramesBarChart framesBarChart;

  bool _paused = false;

  PButton pauseButton;
  PButton resumeButton;
  CoreElement upperButtonSection;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div()..layoutVertical();

    FrameFlameChart flameChart;
    EventDetails eventDetails;

    bool splitterConfigured = false;

    // TODO(kenzie): uncomment these tabs once they are implemented.
//    final PTabNav frameTabNav = PTabNav(<PTabNavTab>[
//      PTabNavTab('Frame Timeline'),
//      PTabNavTab('Widget build info'),
//      PTabNavTab('Skia picture'),
//    ]);

    pauseButton = PButton.icon('Pause recording', FlutterIcons.pause_white_2x)
      ..small()
      ..primary()
      ..click(_pauseRecording);

    resumeButton =
        PButton.icon('Resume recording', FlutterIcons.resume_black_disabled_2x)
          ..small()
          ..clazz('margin-left')
          ..disabled = true
          ..click(_resumeRecording);

    upperButtonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group')
          ..add([
            pauseButton,
            resumeButton,
          ]),
        div()..flex(),
      ]);

    _maybeAddDebugDumpButton();

    screenDiv.add(<CoreElement>[
      upperButtonSection,
      div(c: 'section')
        ..add(framesBarChart = FramesBarChart(timelineController)),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add(<CoreElement>[
          flameChart = FrameFlameChart()..attribute('hidden'),
          eventDetails = EventDetails()..attribute('hidden'),
        ]),
    ]);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

    framesBarChart.onSelectedFrame.listen((TimelineFrame frame) {
      if (frame != null && timelineController.hasStarted) {
        flameChart.attribute('hidden', frame == null);
        eventDetails.attribute('hidden', frame == null);

        flameChart.updateFrameData(frame);
        eventDetails.reset();

        // Configure the flame chart / event details splitter if we haven't
        // already.
        if (!splitterConfigured) {
          split.flexSplit(
            [flameChart, eventDetails],
            horizontal: false,
            gutterSize: defaultSplitterWidth,
            sizes: [75, 25],
            minSize: [200, 60],
          );
          splitterConfigured = true;
        }
      }
    });

    onSelectedFlameChartItem.listen(eventDetails.update);

    return screenDiv;
  }

  @override
  void entering() {
    _updateListeningState();
  }

  @override
  void exiting() {
    _updateListeningState();
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    serviceManager.service.onEvent('Timeline').listen((Event event) {
      final List<dynamic> list = event.json['timelineEvents'];
      final List<Map<String, dynamic>> events =
          list.cast<Map<String, dynamic>>();

      for (Map<String, dynamic> json in events) {
        final TraceEvent e = TraceEvent(json);
        timelineController.timelineData?.processTraceEvent(e);
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    timelineController = null;
  }

  void _pauseRecording() {
    _updateButtons(paused: true);
    _paused = true;
    _updateListeningState();
  }

  void _resumeRecording() {
    _updateButtons(paused: false);
    _paused = false;
    _updateListeningState();
  }

  void _updateButtons({@required bool paused}) {
    pauseButton.disabled = paused;
    resumeButton.disabled = !paused;

    pauseButton.changeIcon(paused
        ? FlutterIcons.pause_white_disabled_2x.src
        : FlutterIcons.pause_white_2x.src);
    resumeButton.changeIcon(paused
        ? FlutterIcons.resume_black_2x.src
        : FlutterIcons.resume_black_disabled_2x.src);
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    final bool shouldBeRunning = !_paused && isCurrentScreen;
    final bool isRunning = !timelineController.paused;

    if (shouldBeRunning && isRunning && !timelineController.hasStarted) {
      await timelineController.startTimeline();
    }

    if (shouldBeRunning && !isRunning) {
      timelineController.resume();

      await serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      await serviceManager.service.setVMTimelineFlags(<String>[]);
      timelineController.pause();
    }
  }

  /// Adds a button to the timeline that will dump debug information to text
  /// files and download them. This will only appear if the [debugTimeline] flag
  /// is true.
  void _maybeAddDebugDumpButton() {
    if (debugTimeline) {
      upperButtonSection.add(PButton('Debug dump')
        ..small()
        ..click(() {
          // TODO(kenzie): we can replace this with something more sophisticated
          // in the future, but for now this is a good debugging addition.

          // Trace events in the order we received them.
          final debugTraceEventsOutput = html.document.createElement('a');
          debugTraceEventsOutput.setAttribute(
              'href',
              html.Url.createObjectUrl(
                  html.Blob([debugTraceEvents.toString()])));
          debugTraceEventsOutput.setAttribute('download', 'trace_output.txt');
          debugTraceEventsOutput.style.display = 'none';
          html.document.body.append(debugTraceEventsOutput);
          debugTraceEventsOutput.click();
          debugTraceEventsOutput.remove();

          // Trace events in the order we handled them.
          final debugHandledTraceEventsOutput =
              html.document.createElement('a');
          debugHandledTraceEventsOutput.setAttribute(
              'href',
              html.Url.createObjectUrl(
                  html.Blob([debugHandledTraceEvents.toString()])));
          debugHandledTraceEventsOutput.setAttribute(
              'download', 'handled_output.txt');
          debugHandledTraceEventsOutput.style.display = 'none';
          html.document.body.append(debugHandledTraceEventsOutput);
          debugHandledTraceEventsOutput.click();
          debugHandledTraceEventsOutput.remove();

          // Significant events in the frame tracking process.
          final debugFrameTrackingOutput = html.document.createElement('a');
          debugFrameTrackingOutput.setAttribute(
              'href',
              html.Url.createObjectUrl(
                  html.Blob([debugFrameTracking.toString()])));
          debugFrameTrackingOutput.setAttribute(
              'download', 'frame_tracking_output.txt');
          debugFrameTrackingOutput.style.display = 'none';
          html.document.body.append(debugFrameTrackingOutput);
          debugFrameTrackingOutput.click();
          debugFrameTrackingOutput.remove();

          // Current status of our frame tracking elements (i.e. pendingEvents,
          // pendingFrames).
          final buf = StringBuffer();
          buf.writeln(
              'Pending events - ${timelineController.timelineData.pendingEvents.length}');
          for (TimelineEvent event
              in timelineController.timelineData.pendingEvents) {
            event.format(buf, '    ');
            buf.writeln();
          }
          buf.writeln(
              '\nPending frames - ${timelineController.timelineData.pendingFrames.length}');
          for (TimelineFrame frame
              in timelineController.timelineData.pendingFrames.values) {
            buf.writeln('${frame.toString()}');
          }
          buf.writeln('\nCurrent CPU event node:');
          timelineController
              .timelineData.eventNodes[TimelineEventType.cpu.index]
              .format(buf, '   ');
          buf.writeln('\n Current GPU event node:');
          timelineController
              .timelineData.eventNodes[TimelineEventType.gpu.index]
              .format(buf, '   ');

          final trackingOutput = html.document.createElement('a');
          trackingOutput.setAttribute(
              'href', html.Url.createObjectUrl(html.Blob([buf.toString()])));
          trackingOutput.setAttribute('download', 'tracking_status.txt');
          trackingOutput.style.display = 'none';
          html.document.body.append(trackingOutput);
          trackingOutput.click();
          trackingOutput.remove();
        }));
    }
  }
}
