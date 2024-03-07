// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import '../../../../../../shared/primitives/utils.dart';
import '../../../../performance_controller.dart';
import '../../../../performance_model.dart';
import '../../timeline_events_controller.dart';
import 'model.dart';

class FlutterTimelineEventProcessor {
  FlutterTimelineEventProcessor(this.performanceController);

  final PerformanceController performanceController;

  TimelineEventsController get eventsController =>
      performanceController.timelineEventsController;

  Int64? _uiTrackId;
  Int64? _rasterTrackId;

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
      // print('adding child ${timelineEvent.name} to ${current.name}');
      current.addChild(timelineEvent);
      currentTimelineEventsByTrackId[trackId] = timelineEvent;
    } else if (event.isUiFrameIdentifier || event.isRasterFrameIdentifier) {
      // We only care about process events that are associated with a Flutter
      // frame.
      // print('setting current for $trackId to ${timelineEvent.name}');
      currentTimelineEventsByTrackId[trackId] = timelineEvent;
    }
  }

  void handleSliceEndEvent(PerfettoTrackEvent event) {
    final trackId = event.trackId;
    var current = currentTimelineEventsByTrackId[trackId];
    if (current == null) return;

    // print('ending ${current.name}');
    current.addEndTrackEvent(event);

    // Since this event is complete, move back up the tree to the nearest
    // incomplete event.
    while (current!.parent != null &&
        current.parent!.time.end?.inMicroseconds != null) {
      // print('moving current up to ${current.parent!.name}');
      current = current.parent;
    }
    currentTimelineEventsByTrackId[trackId] = current.parent;

    // If we have reached a null parent, this event is fully formed - add it to
    // the timeline and try to assign it to a Flutter frame.
    if (current.parent == null) {
      // print(
      //     'adding timeline event with flutter frame number ${current.flutterFrameNumber}');
      // print(current.toString());
      eventsController.addTimelineEvent(current);
    }
  }

  TimelineEventType _inferTrackType(PerfettoTrackEvent event) {
    // Fallback to checking the event name if we don't have a value for
    // [_uiTrackId] or [_rasterTrackId].
    if (_uiTrackId != null && event.trackId == _uiTrackId ||
        event.name == uiEventName) {
      return TimelineEventType.ui;
    }
    if (_rasterTrackId == null && event.trackId == _rasterTrackId ||
        event.name == rasterEventName) {
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
    _uiTrackId ??= ui;
    _rasterTrackId ??= raster;
  }

  void clear() {
    currentTimelineEventsByTrackId.clear();
    _startFrameId = null;
    _endFrameId = null;
  }

  void dispose() {
    clear();
    _uiTrackId = null;
    _rasterTrackId = null;
  }
}
