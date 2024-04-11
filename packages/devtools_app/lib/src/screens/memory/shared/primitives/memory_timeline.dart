// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/primitives/utils.dart';

/// All Raw data received from the VM and offline data loaded from a memory log file.
class MemoryTimeline {
  static const delayMs = 500;
  static const Duration updateDelay = Duration(milliseconds: delayMs);

  /// This flag will be needed for offline mode implementation.
  final offline = false;

  /// Return the data payload that is active.
  List<HeapSample> get data => offline ? offlineData : liveData;

  int get startingIndex => offline ? offlineStartingIndex : liveStartingIndex;

  set startingIndex(int value) {
    offline ? offlineStartingIndex = value : liveStartingIndex = value;
  }

  int get endingIndex => data.isNotEmpty ? data.length - 1 : -1;

  /// Raw Heap sampling data from the VM.
  final List<HeapSample> liveData = [];

  /// Start index of liveData plotted for MPChartData/MPEngineChartData sets.
  int liveStartingIndex = 0;

  /// Data of the last selected offline memory source (JSON file in /tmp).
  final List<HeapSample> offlineData = [];

  /// Start index of offlineData plotted for MPChartData/MPEngineChartData sets.
  int offlineStartingIndex = 0;

  /// Extension Events.
  final _eventFiredNotifier = ValueNotifier<Event?>(null);

  ValueListenable<Event?> get eventNotifier => _eventFiredNotifier;

  /// Notifies that a new Heap sample has been added to the timeline.
  final _sampleAddedNotifier = ValueNotifier<HeapSample?>(null);

  ValueListenable<HeapSample?> get sampleAddedNotifier => _sampleAddedNotifier;

  /// List of events awaiting to be posted to HeapSample.
  final _eventSamples = <EventSample>[];

  void postEventSample(EventSample event) {
/*
    final lastEvent = _eventSamples.safeLast;
    if (lastEvent != null) {
      final lastTime = Duration(milliseconds: lastEvent.timestamp);
      final eventTime = Duration(milliseconds: event.timestamp);
      if ((lastTime + MemoryTimeline.updateDelay).compareTo(eventTime) <= 0) {
        // Coalesce new event to old event.
        _eventSamples.add(EventSample(
//          lastEvent.timestamp,
          event.timestamp,
          lastEvent.isEventGC || event.isEventGC,
          lastEvent.isEventSnapshot || event.isEventSnapshot,
          lastEvent.isEventSnapshotAuto || event.isEventSnapshotAuto,
          lastEvent.allocationAccumulator,
        ));
      }
    }
*/
    _eventSamples.add(event);
  }

  void addSnapshotEvent({bool auto = false}) {
    postEventSample(
      EventSample.snapshotEvent(
        DateTime.now().millisecondsSinceEpoch,
        snapshotAuto: auto,
        events: extensionEvents,
      ),
    );
  }

  void addGCEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    postEventSample(
      EventSample.gcEvent(
        timestamp,
        events: extensionEvents,
      ),
    );
  }

  bool get anyEvents => peekEventTimestamp != -1;

  /// Peek at next event to pull, if no event return -1 timestamp.
  int get peekEventTimestamp {
    final event = _eventSamples.safeFirst;
    return event != null ? event.timestamp : -1;
  }

  /// Grab and remove the event to be posted.
  EventSample pullEventSample() {
    final result = _eventSamples.first;
    _eventSamples.removeAt(0);
    return result;
  }

  final _sampleEventNotifier = ValueNotifier<int>(0);

  ValueNotifier<int> get sampleEventNotifier => _sampleEventNotifier;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  void reset() {
    liveData.clear();
    startingIndex = 0;
  }

  /// Common utility function to handle loading of the data into the
  /// chart for either offline or live Feed.

  static final DateFormat _milliFormat = DateFormat('HH:mm:ss.SSS');

  static String fineGrainTimestampFormat(int timestamp) =>
      _milliFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  void addSample(HeapSample sample) {
    // Always record the heap sample in the raw set of data (liveFeed).
    liveData.add(sample);

    // Only notify that new sample has arrived if the
    // memory source is 'Live Feed'.
    if (!offline) {
      _sampleAddedNotifier.value = sample;
      sampleEventNotifier.value++;
    }
  }

  static const customDevToolsEvent = 'DevTools.Event';
  static const devToolsExtensionEvent = '${customDevToolsEvent}_';

  static bool isCustomEvent(String extensionEvent) =>
      extensionEvent.startsWith(devToolsExtensionEvent);

  static String customEventName(String extensionEventKind) =>
      extensionEventKind.substring(
        MemoryTimeline.devToolsExtensionEvent.length,
      );

  final _extensionEvents = <ExtensionEvent>[];

  bool get anyPendingExtensionEvents => _extensionEvents.isNotEmpty;

  ExtensionEvents? get extensionEvents {
    if (_extensionEvents.isNotEmpty) {
      final eventsToProcess = ExtensionEvents(_extensionEvents.toList());
      _extensionEvents.clear();
      return eventsToProcess;
    }
    return null;
  }

  void addExtensionEvent(
    int? timestamp,
    String? eventKind,
    Map<String, Object> json, {
    String? customEventName,
  }) {
    final extensionEvent = customEventName == null
        ? ExtensionEvent(timestamp, eventKind, json)
        : ExtensionEvent.custom(timestamp, eventKind, customEventName, json);

    _extensionEvents.add(extensionEvent);
  }
}
