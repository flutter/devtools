// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools/service_extensions.dart' as extensions;
import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../framework/framework.dart';
import '../globals.dart';
import '../service_manager.dart' show ServiceExtensionState;
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';
import 'fps.dart';
import 'timeline_protocol.dart';

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

  FramesChart framesChart;
  SetStateMixin framesChartStateMixin = new SetStateMixin();
  FramesTracker framesTracker;
  TimelineFramesBuilder timelineFramesBuilder = new TimelineFramesBuilder();

  TimelineFramesUI timelineFramesUI;

  bool paused = false;

  PButton pauseButton;
  PButton resumeButton;
  PButton trackWidgetBuildsButton;
  PButton perfOverlayButton;
  PButton repaintRainbowButton;
  PButton debugPaintButton;

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

    trackWidgetBuildsButton = createExtensionButton(
        'Track widget builds', extensions.profileWidgetBuilds);
    perfOverlayButton = createExtensionButton(
        'Performance overlay', extensions.performanceOverlay);
    repaintRainbowButton =
        createExtensionButton('Repaint rainbow', extensions.repaintRainbow);
    debugPaintButton =
        createExtensionButton('Debug paint', extensions.debugPaint);

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
              debugPaintButton,
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

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

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

  void _handleConnectionStart(VmServiceWrapper service) {
    // Disables or selects buttons as needed based on the state of their service
    // extensions.
    _updateButtonStates();

    framesChart.disabled = false;

    framesTracker = new FramesTracker(service);
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
        final TimelineEvent e = new TimelineEvent(json);
        timelineFramesUI.timelineData?.processTimelineEvent(e);
      }
    });
  }

  void _updateButtonStates() {
    // Disable buttons for unavailable service extensions.
    serviceManager.serviceExtensionManager
        .hasServiceExtension(extensions.profileWidgetBuilds, (bool available) {
      trackWidgetBuildsButton.disabled = !available;
    });
    serviceManager.serviceExtensionManager
        .hasServiceExtension(extensions.performanceOverlay, (bool available) {
      perfOverlayButton.disabled = !available;
    });
    serviceManager.serviceExtensionManager
        .hasServiceExtension(extensions.repaintRainbow, (bool available) {
      repaintRainbowButton.disabled = !available;
    });
    serviceManager.serviceExtensionManager
        .hasServiceExtension(extensions.debugPaint, (bool available) {
      debugPaintButton.disabled = !available;
    });

    // Select buttons whose state is already enabled.
    serviceManager.serviceExtensionManager.getServiceExtensionState(
        extensions.profileWidgetBuilds, (ServiceExtensionState state) {
      trackWidgetBuildsButton.toggleClass('selected', state.enabled);
    });
    serviceManager.serviceExtensionManager.getServiceExtensionState(
        extensions.performanceOverlay, (ServiceExtensionState state) {
      perfOverlayButton.toggleClass('selected', state.enabled);
    });
    serviceManager.serviceExtensionManager.getServiceExtensionState(
        extensions.repaintRainbow, (ServiceExtensionState state) {
      repaintRainbowButton.toggleClass('selected', state.enabled);
    });
    serviceManager.serviceExtensionManager.getServiceExtensionState(
        extensions.debugPaint, (ServiceExtensionState state) {
      debugPaintButton.toggleClass('selected', state.enabled);
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

      await serviceManager.service
          .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    } else if (!shouldBeRunning && isRunning) {
      // TODO(devoncarew): turn off the events
      await serviceManager.service.setVMTimelineFlags(<String>[]);

      timelineFramesBuilder.pause();
    }
  }

  void _startTimeline() async {
    await serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    await serviceManager.service.clearVMTimeline();

    final Response response = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = response.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TimelineEvent> events = traceEvents
        .map((Map<String, dynamic> event) => new TimelineEvent(event))
        .where((TimelineEvent event) {
      return event.name == 'thread_name';
    }).toList();

    final TimelineData timelineData = new TimelineData();

    for (TimelineEvent event in events) {
      final TimelineThread thread =
          new TimelineThread(timelineData, event.args['name'], event.threadId);
      if (thread.isVisible) {
        timelineData.addThread(thread);
      }
    }

    timelineData.onTimelineThreadEvent.listen((TimelineThreadEvent event) {
      timelineFramesBuilder.processTimelineEvent(
          timelineData.getThread(event.threadId), event);
    });

    timelineFramesUI.timelineData = timelineData;
  }

  // TODO(devoncarew): Update this url.
  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'timeline docs', url: 'http://www.cheese.com');
}

class TimelineFramesUI extends CoreElement {
  TimelineFramesUI(TimelineFramesBuilder timelineFramesBuilder)
      : super('div', classes: 'timeline-frames') {
    timelineFramesBuilder.onFrameAdded.listen((TimelineFrame frame) {
      // TODO(devoncarew): Make sure we respect TimelineFramesBuilder.maxFrames.
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

  TimelineFrameUI selectedFrame;
  TimelineData timelineData;

  final StreamController<TimelineFrame> _selectedFrameController =
      new StreamController<TimelineFrame>.broadcast();

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
    if (frame.rasterizeDuration > (FrameInfo.kTargetMaxFrameTimeMs * 1000)) {
      gpuBar.clazz('slow');
      isSlow = true;
    }
    height = (frame.rasterizeDuration * pixelsPerMs / 1000.0).round();
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

class TimelineFramesBuilder {
  static const int maxFrames = 120;

  List<TimelineFrame> frames = <TimelineFrame>[];

  bool isPaused = false;

  List<TimelineThreadEvent> dartEvents = <TimelineThreadEvent>[];
  List<TimelineThreadEvent> gpuEvents = <TimelineThreadEvent>[];

  final StreamController<TimelineFrame> _frameAddedController =
      new StreamController<TimelineFrame>.broadcast();

  final StreamController<Null> _clearedController =
      new StreamController<Null>.broadcast();

  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  Stream<Null> get onCleared => _clearedController.stream;

  void pause() {
    isPaused = true;

    dartEvents.clear();
    gpuEvents.clear();
  }

  void resume() {
    isPaused = false;
  }

  void processTimelineEvent(TimelineThread thread, TimelineThreadEvent event) {
    if (thread == null) {
      return;
    }

    // io.flutter.1.ui, io.flutter.1.gpu
    if (thread.name.endsWith('.ui')) {
      // PipelineProduce
      if (event.name == 'PipelineProduce' && event.wellFormed) {
        dartEvents.add(event);

        _processSamplesData();
      }
    } else if (thread.name.endsWith('.gpu')) {
      // MessageLoop::RunExpiredTasks
      if (event.name == 'MessageLoop::RunExpiredTasks' && event.wellFormed) {
        gpuEvents.add(event);

        _processSamplesData();
      }
    }
  }

  void _processSamplesData() {
    while (dartEvents.isNotEmpty && gpuEvents.isNotEmpty) {
      int dartStart = dartEvents.first.startMicros;

      // Throw away any gpu samples that start before dart ones.
      while (gpuEvents.isNotEmpty && gpuEvents.first.startMicros < dartStart) {
        gpuEvents.removeAt(0);
      }

      if (gpuEvents.isEmpty) {
        break;
      }

      // Find the newest dart sample that starts before a gpu one.
      final int gpuStart = gpuEvents.first.startMicros;
      while (dartEvents.length > 1 &&
          (dartEvents[0].startMicros < gpuStart &&
              dartEvents[1].startMicros < gpuStart)) {
        dartEvents.removeAt(0);
      }

      if (dartEvents.isEmpty) {
        break;
      }

      // Return the pair.
      dartStart = dartEvents.first.startMicros;
      if (dartStart > gpuStart) {
        break;
      }

      final TimelineThreadEvent dartEvent = dartEvents.removeAt(0);
      final TimelineThreadEvent gpuEvent = gpuEvents.removeAt(0);

      final TimelineFrame frame = new TimelineFrame(
          renderStart: dartEvent.startMicros,
          rasterizeStart: gpuEvent.startMicros);
      frame.renderDuration = dartEvent.durationMicros;
      frame.rasterizeDuration = gpuEvent.durationMicros;

      frames.add(frame);

      if (frames.length > maxFrames) {
        frames.removeAt(0);
      }

      _frameAddedController.add(frame);
    }
  }

  void clear() {
    frames.clear();
    _clearedController.add(null);
  }
}

class FrameDetailsUI extends CoreElement {
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

  TimelineFrameData data;
  CoreElement content;

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
    const double pxPerMicro = microsPerFrame / 1000.0;

    int row = 0;

    final int microsAdjust = data.frame.startMicros;

    int maxRow = 0;

    Function drawRecursively;

    drawRecursively = (TimelineThreadEvent event, int row) {
      if (!event.wellFormed) {
        print('event not well formed: $event');
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

      for (TimelineThreadEvent child in event.children) {
        drawRecursively(child, row + 1);
      }
    };

    try {
      for (TimelineThread thread in data.threads) {
        _createPosition(thread.name, 0, null, row * rowHeight);

        maxRow = row;

        for (TimelineThreadEvent event in data.eventsForThread(thread)) {
          drawRecursively(event, row);
        }

        row = maxRow;

        row++;
      }
    } catch (e, st) {
      print('$e\n$st');
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
