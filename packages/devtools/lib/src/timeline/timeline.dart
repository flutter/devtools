// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../vm_service_wrapper.dart';
import 'frame_flame_chart.dart';
import 'frame_rendering.dart';
import 'frame_rendering_chart.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

const Color slowFrameColor = Color(0xFFf97c7c);
const Color normalFrameColor = Color(0xFF4078c0);

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-drawn during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): use colors for the category

// TODO:(devoncarew): show the total frame count

// TODO(devoncarew): Have a timeline view thumbnail overview.

// TODO(devoncarew): Switch to showing all timeline events, but highlighting the
// area associated with the selected frame.

class TimelineScreen extends Screen {
  TimelineScreen()
      : super(name: 'Timeline', id: 'timeline', iconClass: 'octicon-pulse');

  TimelineController timelineController = TimelineController();
  FramesChart framesChart;
  SetStateMixin framesChartStateMixin = SetStateMixin();
  FramesTracker framesTracker;

  TimelineFramesUI timelineFramesUI;

  bool _paused = false;

  PButton pauseButton;
  PButton resumeButton;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div()..layoutVertical();

    FrameFlameChart frameFlameChart;

    pauseButton = PButton.icon('Pause recording', FlutterIcons.pause_white_2x)
      ..small()
      ..primary()
      ..click(_pauseRecording);

    resumeButton =
        PButton.icon('Resume Recording', FlutterIcons.resume_black_disabled_2x)
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
    upperButtonSection.add(getServiceExtensionButtons());

    screenDiv.add(<CoreElement>[
      upperButtonSection,
      div(c: 'section'),
      createLiveChartArea(),
      div(c: 'section')
        ..add(<CoreElement>[
          timelineFramesUI = TimelineFramesUI(timelineController)
        ]),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add(frameFlameChart = FrameFlameChart()..attribute('hidden')),
    ]);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

    timelineFramesUI.onSelectedFrame.listen((TimelineFrame frame) {
      frameFlameChart.attribute('hidden', frame == null);

      if (frame != null && timelineController.hasStarted) {
        frameFlameChart.updateFrameData(frame);
      }
    });

    return screenDiv;
  }

  CoreElement createLiveChartArea() {
    final CoreElement container = div(c: 'section perf-chart table-border')
      ..layoutVertical();
    framesChart = FramesChart(container);
    framesChart.disabled = true;
    return container;
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
    framesChart.disabled = false;

    framesTracker = FramesTracker(service);
    framesTracker.start();

    framesTracker.onChange.listen((Null _) {
      framesChartStateMixin.setState(() {
        framesChart.updateFrom(framesTracker);
      });
    });

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
    framesChart.disabled = true;
    framesTracker?.stop();
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

  void _updateButtons({@required paused}) {
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
      framesTracker.resume();
      timelineController.resume();

      await serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      await serviceManager.service.setVMTimelineFlags(<String>[]);
      framesTracker.pause();
      timelineController.pause();
    }
  }
}

class TimelineFramesUI extends CoreElement {
  TimelineFramesUI(TimelineController timelineController)
      : super('div', classes: 'timeline-frames') {
    timelineController.onFrameAdded.listen((TimelineFrame frame) {
      final CoreElement frameUI = TimelineFrameUI(this, frame);
      if (element.children.isEmpty) {
        add(frameUI);
      } else {
        if (element.children.length >= timelineController.maxFrames) {
          element.children.removeLast();
        }
        element.children.insert(0, frameUI.element);
      }
    });

    timelineController.onFramesCleared.listen((Null _) {
      clear();
      setSelected(null);
    });
  }

  TimelineFrameUI selectedFrame;

  final StreamController<TimelineFrame> _selectedFrameController =
      StreamController<TimelineFrame>.broadcast();

  Stream<TimelineFrame> get onSelectedFrame => _selectedFrameController.stream;

  void setSelected(TimelineFrameUI frameUI) {
    if (selectedFrame == frameUI) {
      frameUI = null;
    }

    if (selectedFrame != frameUI) {
      selectedFrame?.setSelected(false);
      selectedFrame = frameUI;
      selectedFrame?.setSelected(true);

      _selectedFrameController.add(selectedFrame?.frame);
    }
  }
}

class TimelineFrameUI extends CoreElement {
  TimelineFrameUI(this.framesUI, this.frame)
      : super('div', classes: 'timeline-frame') {
    add(<CoreElement>[
      span(text: 'dart ${frame.cpuAsMs}', c: 'perf-label'),
      CoreElement('br'),
      span(text: 'gpu ${frame.gpuAsMs}', c: 'perf-label'),
    ]);

    const double pixelsPerMs =
        (80.0 - 6) / (FrameInfo.kTargetMaxFrameTimeMs * 2);

    bool isSlow = false;

    // TODO(kenzie): add a helper method to draw a bar given a duration and a
    //  style.
    final CoreElement dartBar = div(c: 'perf-bar left');
    if (frame.cpuDuration > (FrameInfo.kTargetMaxFrameTimeMs * 1000)) {
      dartBar.clazz('slow');
      isSlow = true;
    }
    int height = (frame.cpuDuration * pixelsPerMs / 1000.0).round();
    height = math.min(height, 80 - 6);
    dartBar.element.style.height = '${height}px';
    add(dartBar);

    final CoreElement gpuBar = div(c: 'perf-bar right');
    if (frame.gpuDuration > (FrameInfo.kTargetMaxFrameTimeMs * 1000)) {
      gpuBar.clazz('slow');
      isSlow = true;
    }
    height = (frame.gpuDuration * pixelsPerMs / 1000.0).round();
    height = math.min(height, 80 - 6);
    gpuBar.element.style.height = '${height}px';
    add(gpuBar);

    if (isSlow) {
      clazz('slow');
    }

    click(() {
      framesUI.setSelected(this);
    });
  }

  final TimelineFramesUI framesUI;
  final TimelineFrame frame;

  void setSelected(bool selected) {
    toggleClass('selected', selected);
  }
}
