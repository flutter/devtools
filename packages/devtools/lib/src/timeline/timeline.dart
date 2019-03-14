// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/split.dart' as split;
import '../ui/theme.dart';
import '../ui/ui_utils.dart';
import '../vm_service_wrapper.dart';
import 'event_details.dart';
import 'frame_flame_chart.dart';
import 'frames_bar_chart.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

// Blue 300 (light mode) or 400 (dark mode) from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const mainCpuLight = Color(0xFF64B5F6);
const mainCpuDark = Color(0xFF42A5F5);
const mainCpuColor = ThemedColor(mainCpuLight, mainCpuDark);

// Teal 300 (light mode) or 400 (dark mode) from
// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const mainGpuLight = Color(0xFF4DB6AC);
const mainGpuDark = Color(0xFF26A69A);
const mainGpuColor = ThemedColor(mainGpuLight, mainGpuDark);

const selectedFlameChartItemColor =
    ThemedColor(Color(0xFF4078C0), Color(0xFFFFFFFF));

// Chart is Teal 300 is light, Teal 500 is dark
const gpuChartColor = ThemedColor(mainGpuLight, Color(0xFF009688));
// Chart is Blue 300 is light, Blue 500 is dark
const cpuChartColor = ThemedColor(mainCpuLight, Color(0xFF03A9F4));

// Red 300 is light, Red 500 is dark
const gpuJankColor = ThemedColor(Color(0xFFE57373), Color(0xFFF44336));
// Red 800 is light, Red 800 is dark
const cpuJankColor = ThemedColor(Color(0xFFC62828), Color(0xFFC62828));
// Red 500 is light, Red 700 is dark
const hoverJankColor = ThemedColor(Color(0xFFF44336), Color(0xFFD32F2F));

const Color slowFrameColor = Color(0xFFE50C0C);

// Blue A700 is light, Indigo A400 is dark
const Color selectedGpuColor =
    ThemedColor(Color(0xFF2962FF), Color(0xFF3D5AFE));
// Dark Blue is light, Indigo A200 is dark
const Color selectedCpuColor =
    ThemedColor(Color(0xFF09007E), Color(0xFF536DFE));

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
    final CoreElement upperButtonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group')
          ..add([
            pauseButton,
            resumeButton,
          ]),
        div()..flex(),
      ]);

    screenDiv.add(<CoreElement>[
      upperButtonSection,
      div(c: 'section section-border')
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
        timelineController.timelineData?.processTimelineEvent(e);
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
}
