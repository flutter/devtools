// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import 'fps.dart';

// TODO(devoncarew): expose perf debugging toggles (ext.flutter.repaintRainbow,
//       ext.flutter.showPerformanceOverlay, others)

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-draw during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): use colors for the category

class TimelineScreen extends Screen {
  FramesChart framesChart;
  SetStateMixin framesChartStateMixin = new SetStateMixin();
  FramesTracker framesTracker;
  TimelineFramesBuilder timelineFramesBuilder = new TimelineFramesBuilder();

  TimelineFramesUI timelineFramesUI;

  TimelineScreen()
      : super(name: 'Timeline', id: 'timeline', iconClass: 'octicon-pulse');

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    FrameDetailsUI frameDetailsUI;

    // TODO(devoncarew): pause and resume

    final PButton debugDrawButton = new PButton('Debug draw')..small();
    final PButton perfOverlayButton = new PButton('Performance overlay')
      ..small();
    final PButton debugBannerButton = new PButton('Debug banner')
      ..small()
      ..clazz('selected');

    mainDiv.add(<CoreElement>[
      createLiveChartArea(),
      div(c: 'section'),
      div(c: 'section')
        ..layoutHorizontal()
        ..add(<CoreElement>[
          new PButton('Start timeline recording')
            ..small()
            ..primary()
            ..click(_startTimeline),
          new PButton('Stop recording')
            ..small()
            ..clazz('margin-left')
            ..click(_stopTimeline),
          div()..flex(),
          div(c: 'btn-group')
            ..add(<CoreElement>[
              debugDrawButton,
              perfOverlayButton,
              debugBannerButton,
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

    debugDrawButton.click(() {
      final bool wasSelected =
          debugDrawButton.element.classes.contains('selected');
      debugDrawButton.toggleClass('selected');
      serviceInfo.service.callServiceExtension('ext.flutter.debugPaint',
          isolateId: serviceInfo.isolateManager.selectedIsolate.id,
          args: <String, bool>{'enabled': !wasSelected});
    });

    perfOverlayButton.click(() {
      final bool wasSelected =
          perfOverlayButton.element.classes.contains('selected');
      perfOverlayButton.toggleClass('selected');
      serviceInfo.service.callServiceExtension(
          'ext.flutter.showPerformanceOverlay',
          isolateId: serviceInfo.isolateManager.selectedIsolate.id,
          args: <String, bool>{'enabled': !wasSelected});
    });

    debugBannerButton.click(() {
      final bool wasSelected =
          debugBannerButton.element.classes.contains('selected');
      debugBannerButton.toggleClass('selected');
      serviceInfo.service.callServiceExtension('ext.flutter.debugAllowBanner',
          isolateId: serviceInfo.isolateManager.selectedIsolate.id,
          args: <String, bool>{'enabled': !wasSelected});
    });

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);

    timelineFramesUI.onSelectedFrame.listen((TimelineFrame frame) {
      frameDetailsUI.attribute('hidden', frame == null);

      // TODO(devoncarew): allow frame selection while recording data
      if (frame != null && timelineFramesUI.timelineData != null) {
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
    //print('entering $name');
  }

  @override
  void exiting() {
    //print('exiting $name');
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

  void _startTimeline() async {
    timelineFramesBuilder.clear();
    timelineFramesUI.timelineData = null;

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

  void _stopTimeline() async {
    // http://127.0.0.1:8100/_getCpuProfileTimeline?tags=None&
    //   isolateId=isolates/140204549&timeOriginMicros=225679584415&
    //   timeExtentMicros=35716620

    //timelineData.printData();

    await serviceInfo.service.setVMTimelineFlags(<String>[]);
  }

  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'timeline docs', url: 'http://www.cheese.com');
}

class TimelineData {
  final List<TimelineThread> threads;
  final Map<int, TimelineThread> threadMap = <int, TimelineThread>{};

  final Map<int, TimelineThreadData> threadData = <int, TimelineThreadData>{};

  TimelineData(this.threads) {
    for (TimelineThread thread in threads) {
      threadMap[thread.threadId] = thread;
      threadData[thread.threadId] = new TimelineThreadData(this);
    }
  }

  void processTimelineEvent(TimelineEvent event) {
    final TimelineThread thread = threadMap[event.threadId];
    if (thread == null) {
      return;
    }

    final TimelineThreadData data = threadData[event.threadId];

    switch (event.phase) {
      case 'B':
        data.handleDurationBeginEvent(event);
        break;
      case 'E':
        data.handleDurationEndEvent(event);
        break;
      case 'X':
        data.handleCompleteEvent(event);
        break;

      default:
        // TODO:
        print('unhandled phase: ${event.phase}');
        break;
    }
  }

  TimelineFrameData getFrameData(TimelineFrame frame) {
    if (frame == null) {
      return null;
    }

    final List<TEvent> events = <TEvent>[];

    for (TimelineThreadData data in threadData.values) {
      for (TEvent event in data.events) {
        if (!event.wellFormed) {
          continue;
        }

        if (event.endMicros >= frame.start && event.startMicros < frame.end) {
          events.add(event);
        }
      }
    }

    return TimelineFrameData(frame, threads, events);
  }

  void printData() {
    for (TimelineThread thread in threads) {
      print('${thread.name}:');
      final StringBuffer buf = new StringBuffer();
      final TimelineThreadData data = threadData[thread.threadId];

      for (TEvent event in data.events) {
        event.format(buf, '  ');
        print(buf.toString().trimRight());
        buf.clear();
      }

      print('');
    }
  }
}

class TimelineFrameData {
  final TimelineFrame frame;
  final List<TimelineThread> threads;
  final List<TEvent> events;

  TimelineFrameData(this.frame, this.threads, this.events);

  void printData() {
    for (TimelineThread thread in threads) {
      print('${thread.name}:');
      final StringBuffer buf = new StringBuffer();

      for (TEvent event in events) {
        if (event.threadId == thread.threadId) {
          event.format(buf, '  ');
          print(buf.toString().trimRight());
          buf.clear();
        }
      }
    }
  }

  Iterable<TEvent> eventsForThread(TimelineThread thread) {
    return events.where((TEvent event) => event.threadId == thread.threadId);
  }
}

class TimelineThreadData {
  final TimelineData parent;
  final List<TEvent> events = <TEvent>[];

  TimelineThreadData(this.parent);

  List<TEvent> durationStack = <TEvent>[];

  void handleDurationBeginEvent(TimelineEvent event) {
    final TEvent e = new TEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);

    if (durationStack.isEmpty) {
      events.add(e);
    } else {
      durationStack.last.children.add(e);
    }

    durationStack.add(e);
  }

  void handleDurationEndEvent(TimelineEvent event) {
    if (durationStack.isNotEmpty) {
      final TEvent e = durationStack.removeLast();
      e.setEnd(event.timestampMicros);
    }
  }

  void handleCompleteEvent(TimelineEvent event) {
    final TEvent e = new TEvent(event.threadId, event.name);
    e.setStart(event.timestampMicros);
    e.durationMicros = event.duration;

    if (durationStack.isEmpty) {
      events.add(e);
    } else {
      durationStack.last.children.add(e);
    }
  }
}

class TEvent {
  final int threadId;
  final String name;

  List<TEvent> children = <TEvent>[];

  int startMicros;
  int durationMicros;

  TEvent(this.threadId, this.name);

  void setStart(int micros) {
    startMicros = micros;
  }

  void setEnd(int micros) {
    durationMicros = micros - startMicros;
  }

  int get endMicros => startMicros + (durationMicros ?? 0);

  bool get wellFormed => startMicros != null && durationMicros != null;

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$name');
    for (TEvent child in children) {
      child.format(buf, '  $indent');
    }
  }

  @override
  String toString() => '$name, start=$startMicros duration=$durationMicros';
}

class TimelineThread implements Comparable<TimelineThread> {
  final int threadId;

  String _name;

  TimelineThread(String name, this.threadId) {
    _name = name;

    // "name":"io.flutter.1.ui (42499)",
    if (name.contains(' (') && name.endsWith(')')) {
      _name = name.substring(0, _name.lastIndexOf(' ('));
    }
  }

  bool get isVisible => name.startsWith('io.flutter.');

  int get category {
    if (name.endsWith('.ui')) {
      return 1;
    }
    if (name.endsWith('.gpu')) {
      return 2;
    }
    if (name.startsWith('io.flutter.')) {
      return 3;
    }
    return 4;
  }

  String get name => _name;

  @override
  String toString() => name;

  @override
  int compareTo(TimelineThread other) {
    final int c1 = category;
    final int c2 = other.category;
    if (c1 != c2) {
      return c1 - c2;
    }
    return name.compareTo(other.name);
  }
}

/// A single timeline event.
class TimelineEvent {
  /// Creates a timeline event given JSON-encoded event data.
  factory TimelineEvent(Map<String, dynamic> json) {
    return new TimelineEvent._(json, json['name'], json['cat'], json['ph'],
        json['pid'], json['tid'], json['dur'], json['ts'], json['args']);
  }

  TimelineEvent._(
      this.json,
      this.name,
      this.category,
      this.phase,
      this.processId,
      this.threadId,
      this.duration,
      this.timestampMicros,
      this.args);

  /// The original event JSON.
  final Map<String, dynamic> json;

  /// The name of the event.
  ///
  /// Corresponds to the "name" field in the JSON event.
  final String name;

  /// Event category. Events with different names may share the same category.
  ///
  /// Corresponds to the "cat" field in the JSON event.
  final String category;

  /// For a given long lasting event, denotes the phase of the event, such as
  /// "B" for "event began", and "E" for "event ended".
  ///
  /// Corresponds to the "ph" field in the JSON event.
  final String phase;

  /// ID of process that emitted the event.
  ///
  /// Corresponds to the "pid" field in the JSON event.
  final int processId;

  /// ID of thread that issues the event.
  ///
  /// Corresponds to the "tid" field in the JSON event.
  final int threadId;

  /// The duration of the event, in microseconds.
  ///
  /// Note, some events are reported with duration. Others are reported as a
  /// pair of begin/end events.
  ///
  /// Corresponds to the "dur" field in the JSON event.
  final int duration;

  /// Time passed since tracing was enabled, in microseconds.
  final int timestampMicros;

  /// Arbitrary data attached to the event.
  final Map<String, dynamic> args;

  @override
  String toString() => '[$category] [$phase] $name';
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
  List<TimelineFrame> frames = <TimelineFrame>[];

  final StreamController<TimelineFrame> _frameAddedController =
      new StreamController<TimelineFrame>.broadcast();

  final StreamController<Null> _clearedController =
      new StreamController<Null>.broadcast();

  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  Stream<Null> get onCleared => _clearedController.stream;

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

class TimelineFrame {
  int renderStart;
  int renderDuration;

  int rastereizeStart;
  int rastereizeDuration;

  TimelineFrame();

  int get start => renderStart ?? rastereizeStart;

  int get end {
    if (rastereizeStart != null) {
      return rastereizeStart + rastereizeDuration;
    } else {
      return renderStart + renderDuration;
    }
  }

  void setRenderStart(int micros) {
    renderStart = micros;
  }

  void setRenderEnd(int micros) {
    renderDuration = micros - renderStart;
  }

  void setRastereizeStart(int micros) {
    rastereizeStart = micros;
  }

  void setRastereizeEnd(int micros) {
    if (rastereizeStart != null) {
      rastereizeDuration = micros - rastereizeStart;
    }
  }

  bool get isComplete => renderDuration != null && rastereizeDuration != null;

  String get renderAsMs {
    return '${(renderDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  String get gpuAsMs {
    return '${(rastereizeDuration / 1000.0).toStringAsFixed(1)}ms';
  }

  @override
  String toString() {
    return 'frame render: $renderDuration rasterize: $rastereizeDuration';
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
