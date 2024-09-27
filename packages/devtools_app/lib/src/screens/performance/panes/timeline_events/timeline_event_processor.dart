// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../../shared/development_helpers.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import 'perfetto/tracing/model.dart';
import 'timeline_events_controller.dart';

final _log = Logger('flutter_timeline_event_processor');

class FlutterTimelineEventProcessor {
  FlutterTimelineEventProcessor(this.performanceController);

  final PerformanceController performanceController;

  TimelineEventsController get eventsController =>
      performanceController.timelineEventsController;

  @visibleForTesting
  Int64? uiTrackId;

  @visibleForTesting
  Int64? rasterTrackId;

  /// The Flutter frame range that we have processed track events for.
  Range? get frameRangeFromTimelineEvents =>
      _startFrameId == null || _endFrameId == null
          ? null
          : Range(_startFrameId!, _endFrameId!);
  int? _startFrameId;
  int? _endFrameId;

  /// Returns whether we have processed the trace events that correspond to the
  /// Flutter frame with id [frameId].
  bool hasProcessedEventsForFrame(int frameId) {
    return frameRangeFromTimelineEvents?.contains(frameId) ?? false;
  }

  bool frameIsBeforeTimelineData(int frameId) {
    if (_startFrameId == null) {
      // Since we do not know for certain that [frameId] is out of range, return
      // false.
      return false;
    }
    return frameId < _startFrameId!;
  }

  /// The current timeline event nodes by track id.
  ///
  /// As we process [PerfettoTrackEvent]s, an event on a track will completely
  /// formed before another event on the same track begins.
  @visibleForTesting
  final currentTimelineEventsByTrackId = <Int64, FlutterTimelineEvent?>{};

  /// Process the Perfetto track events to create [FlutterTimelineEvent]s.
  void processTrackEvents(List<PerfettoTrackEvent> events) {
    // [events] must be sorted in increasing timestamp order
    _processTrackEvents(events..sort());
  }

  void _processTrackEvents(List<PerfettoTrackEvent> events) {
    for (final event in events) {
      _maybeSetFrameIds(event);
      event.timelineEventType = _inferTrackType(event);

      switch (event.type) {
        case PerfettoEventType.sliceBegin:
          handleSliceBeginEvent(event);
          break;
        case PerfettoEventType.sliceEnd:
          handleSliceEndEvent(event);
          break;
        case PerfettoEventType.instant:
        default:
          // We do not need to handle instant events because Flutter frame
          // trace events are not sent as instant events.
          break;
      }
    }
  }

  void handleSliceBeginEvent(PerfettoTrackEvent event) {
    final trackId = event.trackId;
    final current = currentTimelineEventsByTrackId[trackId];
    final timelineEvent = FlutterTimelineEvent(event);
    if (current != null) {
      current.addChild(timelineEvent);
      currentTimelineEventsByTrackId[trackId] = timelineEvent;
    } else if (event.isUiFrameIdentifier || event.isRasterFrameIdentifier) {
      // We only care about process events that are associated with a Flutter
      // frame.
      currentTimelineEventsByTrackId[trackId] = timelineEvent;
      debugTraceCallback(
        () => _log.info(
          'Event tree start: ${timelineEvent.name}, trackId: $trackId',
        ),
      );
    }
  }

  void handleSliceEndEvent(PerfettoTrackEvent event) {
    final trackId = event.trackId;
    var current = currentTimelineEventsByTrackId[trackId];
    if (current == null) return;

    current.addEndTrackEvent(event);

    // Since this event is complete, move back up the tree to the nearest
    // incomplete event.
    while (current!.parent != null &&
        current.parent!.time.end?.inMicroseconds != null) {
      current = current.parent;
    }
    currentTimelineEventsByTrackId[trackId] = current.parent;

    // If we have reached a null parent, this event is fully formed - add it to
    // the timeline and try to assign it to a Flutter frame.
    if (current.parent == null) {
      eventsController.addTimelineEvent(current);
      debugTraceCallback(() => _log.info('Event tree complete:\n$current'));
    }
  }

  TimelineEventType _inferTrackType(PerfettoTrackEvent event) {
    // Whether the UI and Raster events are expected to come on a single track.
    // This is expected when DevTools is connected to a flutter-tester device.
    final singleTrackType = uiTrackId != null &&
        rasterTrackId != null &&
        uiTrackId == rasterTrackId;

    // Fallback to checking the event name if we don't have a value for
    // [_uiTrackId] or [_rasterTrackId], or if we expect the events to come on
    // a single track [singleTrackType].
    if ((!singleTrackType && uiTrackId != null && event.trackId == uiTrackId) ||
        event.name == FlutterTimelineEvent.uiEventName) {
      return TimelineEventType.ui;
    }
    if ((!singleTrackType &&
            rasterTrackId != null &&
            event.trackId == rasterTrackId) ||
        event.name == FlutterTimelineEvent.rasterEventName) {
      return TimelineEventType.raster;
    }
    return TimelineEventType.other;
  }

  void _maybeSetFrameIds(PerfettoTrackEvent event) {
    final frameNumberFromEvent = event.flutterFrameNumber;
    if (frameNumberFromEvent != null) {
      _startFrameId ??= frameNumberFromEvent;
      // We process events in timestamp order, so [_endFrameId] will always be
      // reassigned.
      _endFrameId = max(_endFrameId ?? -1, frameNumberFromEvent);
    }
  }

  /// Sets the UI and Raster track ids for the event processor if they are not
  /// already set.
  void primeTrackIds({required Int64? ui, required Int64? raster}) {
    uiTrackId ??= ui;
    rasterTrackId ??= raster;
  }

  void clear() {
    currentTimelineEventsByTrackId.clear();
    _startFrameId = null;
    _endFrameId = null;
  }

  void dispose() {
    clear();
    uiTrackId = null;
    rasterTrackId = null;
  }
}
