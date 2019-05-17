// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:convert';

import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../globals.dart';
import 'timeline_protocol.dart';

const String timelineScreenId = 'timeline';

final loadTimelineSnapshotController =
    StreamController<TimelineSnapshot>.broadcast();

Stream<TimelineSnapshot> get onLoadTimelineSnapshot =>
    loadTimelineSnapshotController.stream;

/// This class contains the business logic for [timeline.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class TimelineController {
  TimelineController() {
    onLoadTimelineSnapshot.listen(_loadTimelineFromSnapshot);
  }

  final StreamController<TimelineFrame> _frameAddedController =
      StreamController<TimelineFrame>.broadcast();
  Stream<TimelineFrame> get onFrameAdded => _frameAddedController.stream;

  TimelineData _timelineData;

  TimelineData get timelineData => _timelineData;

  bool get hasStarted => timelineData != null;

  bool get paused => _paused;

  bool _paused = false;

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  Future<void> startTimeline() async {
    await serviceManager.serviceAvailable.future;
    await serviceManager.service
        .setVMTimelineFlags(<String>['GC', 'Dart', 'Embedder']);
    await serviceManager.service.clearVMTimeline();

    final Response response = await serviceManager.service.getVMTimeline();
    final List<dynamic> list = response.json['traceEvents'];
    final List<Map<String, dynamic>> traceEvents =
        list.cast<Map<String, dynamic>>();

    final List<TraceEvent> events = traceEvents
        .map((Map<String, dynamic> event) => TraceEvent(event))
        .where((TraceEvent event) {
      return event.name == 'thread_name';
    }).toList();

    // TODO(kenzie): Remove this logic once ui/gpu distinction changes are
    // available in the engine.
    int uiThreadId;
    int gpuThreadId;
    for (TraceEvent event in events) {
      // iOS - 'io.flutter.1.ui', Android - '1.ui'.
      if (event.args['name'].contains('1.ui')) {
        uiThreadId = event.threadId;
      }
      // iOS - 'io.flutter.1.gpu', Android - '1.gpu'.
      if (event.args['name'].contains('1.gpu')) {
        gpuThreadId = event.threadId;
      }
    }

    final TimelineData timelineData = TimelineData(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    timelineData.onFrameCompleted.listen((frame) {
      _frameAddedController.add(frame);
    });

    _timelineData = timelineData;
  }

  void _loadTimelineFromSnapshot(TimelineSnapshot snapshot) {
    final traceEvents =
        snapshot.traceEvents.map((trace) => TraceEvent(trace)).toList();

    // TODO(kenzie): once each trace event has a ui/gpu distinction bit added to
    // the trace, we will not need to infer thread ids. Since we control the
    // format of the input, this is okay for now.
    final uiThreadId = traceEvents.first.threadId;
    final gpuThreadId = traceEvents.last.threadId;

    final TimelineData timelineData = TimelineData(
      uiThreadId: uiThreadId,
      gpuThreadId: gpuThreadId,
    );

    timelineData.onFrameCompleted.listen((frame) {
      _frameAddedController.add(frame);
    });

    _timelineData = timelineData;

    for (TraceEvent event in traceEvents) {
      timelineData.processTraceEvent(event, immediate: true);
    }
    // Make a final call to [maybeAddPendingEvents] so that we complete the
    // processing for every frame in the snapshot.
    timelineData.maybeAddPendingEvents();
  }

  void exitSnapshotMode() {
    // If the timeline controller had previously been started, restart it
    // because [_timelineData] has changed since we entered snapshot mode.
    if (hasStarted) {
      startTimeline();
    }
  }
}

class TimelineSnapshot {
  TimelineSnapshot._(
    this.traceEvents,
    this.cpuProfile,
    this.selectedEvent,
  );

  static TimelineSnapshot from(
    List<Map<String, dynamic>> traceEvents,
    Map<String, dynamic> cpuProfile,
    TimelineEvent selectedEvent,
  ) {
    final _traceEvents = traceEvents ?? [];
    final _cpuProfile = cpuProfile ?? {};
    final _selectedEvent = selectedEvent != null
        ? TimelineEventSnapshot(
            selectedEvent.name,
            selectedEvent.time.start.inMicroseconds,
            selectedEvent.time.duration.inMicroseconds,
          )
        : null;
    return TimelineSnapshot._(_traceEvents, _cpuProfile, _selectedEvent);
  }

  static TimelineSnapshot parse(Map<String, dynamic> json) {
    final List<dynamic> traceEvents =
        (json[traceEventsKey] ?? []).cast<Map<String, dynamic>>();
    final Map<String, dynamic> cpuProfile = json[cpuProfileKey] ?? {};
    final Map<String, dynamic> selectedEventData = json[selectedEventKey];
    final selectedEvent = selectedEventData.isNotEmpty
        ? TimelineEventSnapshot(
            selectedEventData[TimelineEventSnapshot.eventNameKey],
            selectedEventData[TimelineEventSnapshot.eventStartTimeKey],
            selectedEventData[TimelineEventSnapshot.eventDurationKey],
          )
        : null;

    return TimelineSnapshot._(traceEvents, cpuProfile, selectedEvent);
  }

  static const traceEventsKey = 'traceEvents';
  static const cpuProfileKey = 'cpuProfile';
  static const selectedEventKey = 'selectedEvent';
  static const devToolsScreenKey = 'dartDevToolsScreen';

  final List<Map<String, dynamic>> traceEvents;

  final Map<String, dynamic> cpuProfile;

  final TimelineEventSnapshot selectedEvent;

  String get encodedJson {
    final json = {
      traceEventsKey: traceEvents,
      cpuProfileKey: cpuProfile,
      selectedEventKey: selectedEvent?.json ?? {},
      devToolsScreenKey: timelineScreenId,
    };
    return jsonEncode(json);
  }

  bool get isEmpty => traceEvents.isEmpty && cpuProfile.isEmpty;

  bool get hasCpuProfile => cpuProfile.isNotEmpty && selectedEvent != null;
}

/// Wrapper class for [TimelineEvent] that only includes information we need for
/// importing and exporting snapshots.
///
/// * name
/// * start time
/// * duration
///
/// We extend TimelineEvent so that our CPU profiler code requiring a selected
/// timeline event will work as it does when we are not loading from a snapshot.
class TimelineEventSnapshot extends TimelineEvent {
  TimelineEventSnapshot(String name, int startMicros, int durationMicros)
      : super(TraceEventWrapper(
          TraceEvent({
            'name': name,
            'ts': startMicros,
            'dur': durationMicros,
            'args': {'type': 'ui'},
          }),
          0, // 0 is an arbitrary value for [TraceEventWrapper.timeReceived].
        )) {
    time.end = Duration(microseconds: startMicros + durationMicros);
  }

  static const eventNameKey = 'name';
  static const eventStartTimeKey = 'startMicros';
  static const eventDurationKey = 'durationMicros';

  Map<String, dynamic> get json {
    return {
      eventNameKey: name,
      eventStartTimeKey: time.start.inMicroseconds,
      eventDurationKey: time.duration.inMicroseconds,
    };
  }
}
