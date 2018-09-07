// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import 'fps.dart';
import 'timeline_protocol.dart';

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-drawn during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): use colors for the category

class TimelineScreen extends Screen {
  TimelineScreen()
      : super(name: 'Timeline', id: 'timeline', iconClass: 'octicon-pulse');

  FramesChart framesChart;
  SetStateMixin framesChartStateMixin = new SetStateMixin();
  FramesTracker framesTracker;
  TimelineFramesBuilder timelineFramesBuilder = new TimelineFramesBuilder();

  TimelineFramesUI timelineFramesUI;

  bool paused = false;

  PButton pauseButton;
  PButton resumeButton;

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    FrameDetailsUI frameDetailsUI;

    pauseButton = new PButton('Pause recording')
      ..small()
      ..primary()
      ..click(_pauseRecording);

    resumeButton = new PButton('Resume recording')
      ..small()
      ..clazz('margin-left')
      ..disabled = true
      ..click(_resumeRecording);

    final PButton trackWidgetBuildsButton = new PButton('Track widget builds')
      ..small();
    final PButton perfOverlayButton = new PButton('Performance overlay')
      ..small();
    final PButton repaintRainbowButton = new PButton('Repaint rainbow')
      ..small();
    final PButton debugDrawButton = new PButton('Debug draw')..small();

    mainDiv.add(<CoreElement>[
      createLiveChartArea(),
      div(c: 'section'),
      div(c: 'section')
        ..layoutHorizontal()
        ..add(<CoreElement>[
          pauseButton,
          resumeButton,
          div()..flex(),
          div(c: 'btn-group')
            ..add(<CoreElement>[
              trackWidgetBuildsButton,
              perfOverlayButton,
              repaintRainbowButton,
              debugDrawButton,
            ]),
        ]),
      div(c: 'section')
        ..add(<CoreElement>[
          timelineFramesUI = new TimelineFramesUI(timelineFramesBuilder)
        ]),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add(frameDetailsUI = new FrameDetailsUI()..attribute('hidden')),
    ]);

    void handleToggleButton(PButton button, String serviceCallName) {
      button.click(() {
        final bool wasSelected = button.element.classes.contains('selected');
        button.toggleClass('selected');
        serviceInfo.service.callServiceExtension(
          serviceCallName,
          isolateId: serviceInfo.isolateManager.selectedIsolate.id,
          args: <String, bool>{'enabled': !wasSelected},
        );
      });
    }

    handleToggleButton(
        trackWidgetBuildsButton, 'ext.flutter.debugProfileBuilds');
    handleToggleButton(perfOverlayButton, 'ext.flutter.showPerformanceOverlay');
    handleToggleButton(repaintRainbowButton, 'ext.flutter.repaintRainbow');
    handleToggleButton(debugDrawButton, 'ext.flutter.debugPaint');

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);

    timelineFramesUI.onSelectedFrame.listen((TimelineFrame frame) {
      frameDetailsUI.attribute('hidden', frame == null);

      if (frame != null && timelineFramesUI.hasStarted()) {
        final TimelineFrameData data =
            timelineFramesUI.timelineData.getFrameData(frame);
        frameDetailsUI.updateData(data);
      }
    });
  }

  CoreElement createLiveChartArea() {
    final CoreElement container = div(c: 'section perf-chart table-border')
      ..layoutVertical();
    framesChart = new FramesChart(container);
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

  void _handleConnectionStart(VmService service) {
    framesChart.disabled = false;

    framesTracker = new FramesTracker(service);
    framesTracker.start();

    framesTracker.onChange.listen((Null _) {
      framesChartStateMixin.setState(() {
        framesChart.updateFrom(framesTracker);
      });
    });

    serviceInfo.service.onEvent('Timeline').listen((Event event) {
      final List<dynamic> list = event.json['timelineEvents'];
      final List<Map<String, dynamic>> events =
          list.cast<Map<String, dynamic>>();

      for (Map<String, dynamic> json in events) {
        final TimelineEvent e = new TimelineEvent(json);

        timelineFramesBuilder.processTimelineEvent(e);
        timelineFramesUI.timelineData?.processTimelineEvent(e);
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    framesChart.disabled = true;

    framesTracker?.stop();
  }

  void _pauseRecording() {
    pauseButton.disabled = true;
    resumeButton.disabled = false;

    paused = true;

    _updateListeningState();
  }

  void _resumeRecording() {
    pauseButton.disabled = false;
    resumeButton.disabled = true;

    paused = false;

    _updateListeningState();
  }

  void _updateListeningState() async {
    final bool shouldBeRunning = !paused && isCurrentScreen;
    final bool isRunning = !timelineFramesBuilder.isPaused;

    if (shouldBeRunning && isRunning && !timelineFramesUI.hasStarted()) {
      _startTimeline();
    }

    if (shouldBeRunning && !isRunning) {
      timelineFramesBuilder.resume();

      await serviceInfo.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    } else if (!shouldBeRunning && isRunning) {
      // TODO: turn off the events
      await serviceInfo.service.setVMTimelineFlags(<String>[]);

      timelineFramesBuilder.pause();
    }
  }

  void _startTimeline() async {
    await serviceInfo.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    await serviceInfo.service.clearVMTimeline();

    final Response response = await serviceInfo.service.getVMTimeline();
    final List<dynamic> list = response.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TimelineEvent> events = traceEvents
        .map((Map<String, dynamic> event) => new TimelineEvent(event))
        .where((TimelineEvent event) {
      return event.name == 'thread_name';
    }).toList();

    List<TimelineThread> threads = events
        .map((TimelineEvent event) =>
            new TimelineThread(event.args['name'], event.threadId))
        .toList();

    threads =
        threads.where((TimelineThread thread) => thread.isVisible).toList();
    threads.sort();

    timelineFramesUI.timelineData = new TimelineData(threads);
  }

  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'timeline docs', url: 'http://www.cheese.com');
}

class TimelineFramesUI extends CoreElement {
  TimelineFrameUI selectedFrame;
  TimelineData timelineData;

  final StreamController<TimelineFrame> _selectedFrameController =
      new StreamController<TimelineFrame>.broadcast();

  TimelineFramesUI(TimelineFramesBuilder timelineFramesBuilder)
      : super('div', classes: 'timeline-frames') {
    timelineFramesBuilder.onFrameAdded.listen((TimelineFrame frame) {
      final CoreElement frameUI = new TimelineFrameUI(this, frame);
      if (element.children.isEmpty) {
        add(frameUI);
      } else {
        element.children.insert(1, frameUI.element);
      }
    });

    timelineFramesBuilder.onCleared.listen((Null _) {
      clear();

      setSelected(null);
    });
  }

  bool hasStarted() => timelineData != null;

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
  final TimelineFramesUI framesUI;
  final TimelineFrame frame;

  TimelineFrameUI(this.framesUI, this.frame)
      : super('div', classes: 'timeline-frame') {
    add(<CoreElement>[
      span(text: 'dart ${frame.renderAsMs}', c: 'perf-label'),
      new CoreElement('br'),
      span(text: 'gpu ${frame.gpuAsMs}', c: 'perf-label'),
    ]);

    const double pixelsPerMs =
        (80.0 - 6) / (FrameInfo.kTargetMaxFrameTimeMs * 2);

    bool isSlow = false;

    final CoreElement dartBar = div(c: 'perf-bar left');
    if (frame.renderDuration > (FrameInfo.kTargetMaxFrameTimeMs * 1000)) {
      dartBar.clazz('slow');
      isSlow = true;
    }
    int height = (frame.renderDuration * pixelsPerMs / 1000.0).round();
    height = math.min(height, 80 - 6);
    dartBar.element.style.height = '${height}px';
    add(dartBar);

    final CoreElement gpuBar = div(c: 'perf-bar right');
    if (frame.rastereizeDuration > (FrameInfo.kTargetMaxFrameTimeMs * 1000)) {
      gpuBar.clazz('slow');
      isSlow = true;
    }
    height = (frame.rastereizeDuration * pixelsPerMs / 1000.0).round();
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

  void setSelected(bool selected) {
    toggleClass('selected', selected);
  }
}

class TimelineFramesBuilder {
  static const int maxFrames = 120;

  List<TimelineFrame> frames = <TimelineFrame>[];

  bool isPaused = false;

  final StreamController<TimelineFrame> _frameAddedController =
      new StreamController<TimelineFrame>.broadcast();

  final StreamController<Null> _clearedController =
      new StreamController<Null>.broadcast();

  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  Stream<Null> get onCleared => _clearedController.stream;

  void pause() {
    isPaused = true;

    if (frames.isNotEmpty && !frames.last.isComplete) {
      frames.removeLast();
    }
  }

  void resume() {
    isPaused = false;
  }

  void processTimelineEvent(TimelineEvent event) {
    if (event.category != 'Embedder') {
      return;
    }

    // [Embedder] [B] VSYNC
    if (event.name == 'VSYNC') {
      if (event.phase == 'B') {
        TimelineFrame frame = findFrameAfter(event.timestampMicros);
        if (frame == null) {
          frame = new TimelineFrame();
          frames.add(frame);
        }
        frame.setRenderStart(event.timestampMicros);
      } else if (event.phase == 'E') {
        final TimelineFrame frame = findFrameBefore(event.timestampMicros);
        frame?.setRenderEnd(event.timestampMicros);

        if (frame != null && frame.isComplete) {
          _frameAddedController.add(frame);
        }
      }
    }

    // [Embedder] [B] GPURasterizer::Draw
    if (event.name == 'GPURasterizer::Draw') {
      if (event.phase == 'B') {
        TimelineFrame frame = findFrameBefore(event.timestampMicros);
        if (frame == null) {
          frame = new TimelineFrame();
          frames.add(frame);
          if (frames.length > maxFrames) {
            frames.removeAt(0);
          }
        }
        frame.setRastereizeStart(event.timestampMicros);
      } else if (event.phase == 'E') {
        final TimelineFrame frame = findFrameBefore(event.timestampMicros);
        frame?.setRastereizeEnd(event.timestampMicros);

        if (frame != null && frame.isComplete) {
          _frameAddedController.add(frame);
        }
      }
    }
  }

  TimelineFrame findFrameAfter(int micros) {
    for (TimelineFrame frame in frames) {
      if (frame.start > micros) {
        return frame;
      }
    }

    return null;
  }

  TimelineFrame findFrameBefore(int micros) {
    for (TimelineFrame frame in frames.reversed) {
      if (frame.start <= micros) {
        return frame;
      }
    }

    return null;
  }

  void clear() {
    frames.clear();
    _clearedController.add(null);
  }
}

class FrameDetailsUI extends CoreElement {
  TimelineFrameData data;

  CoreElement content;

  FrameDetailsUI() : super('div') {
    layoutVertical();
    flex();

    // TODO(devoncarew): listen to tab changes
    content = div(c: 'frame-timeline')..flex();

    final PTabNav tabNav = new PTabNav(<PTabNavTab>[
      new PTabNavTab('Frame timeline'),
      new PTabNavTab('Widget build info'),
      new PTabNavTab('Skia picture'),
    ]);

    add(<CoreElement>[
      tabNav,
      content,
    ]);

    content.element.style.whiteSpace = 'pre';
    content.element.style.overflow = 'scroll';
  }

  void updateData(TimelineFrameData data) {
    this.data = data;

    content.clear();

//    if (data != null) {
//      StringBuffer buf = new StringBuffer();
//
//      for (TimelineThread thread in data.threads) {
//        buf.writeln('${thread.name}:');
//
//        for (TEvent event in data.events) {
//          if (event.threadId == thread.threadId) {
//            event.format(buf, '  ');
//          }
//        }
//      }
//
//      content.text = buf.toString();
//    }

    if (data != null) {
      _render(data);
    }
  }

  void _render(TimelineFrameData data) {
    const int leftIndent = 130;
    const int rowHeight = 25;

    const double microsPerFrame = 1000 * 1000 / 60.0;
    const double pxPerMicro = microsPerFrame / 1200.0;

    int row = 0;

    final int microsAdjust = data.frame.start;

    int maxRow = 0;

    Function drawRecursively;

    drawRecursively = (TEvent event, int row) {
      if (!event.wellFormed) {
        print('event not well formed');
        print(event);
        return;
      }

      final double start = (event.startMicros - microsAdjust) / pxPerMicro;
      final double end =
          (event.startMicros - microsAdjust + event.durationMicros) /
              pxPerMicro;

      _createPosition(event.name, leftIndent + start.round(),
          (end - start).round(), row * rowHeight);

      if (row > maxRow) {
        maxRow = row;
      }

      for (TEvent child in event.children) {
        drawRecursively(child, row + 1);
      }
    };

    try {
      for (TimelineThread thread in data.threads) {
        _createPosition(thread.name, 0, null, row * rowHeight);

        maxRow = row;

        for (TEvent event in data.eventsForThread(thread)) {
          drawRecursively(event, row);
        }

        row = maxRow;

        row++;
      }
    } catch (e, st) {
      print(e);
      print(st);
    }
  }

  void _createPosition(String name, int left, int width, int top) {
    final CoreElement item = div(text: name, c: 'timeline-title');
    item.element.style.left = '${left}px';
    if (width != null) {
      item.element.style.width = '${width}px';
    }
    item.element.style.top = '${top}px';
    content.add(item);
  }
}
