// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/logger.dart';
import '../../primitives/utils.dart';

enum ContinuesState {
  none,
  start,
  stop,
  next,
}

/// All Raw data received from the VM and offline data loaded from a memory log file.
class MemoryTimeline {
  MemoryTimeline(this.offline);

  /// Version of timeline data (HeapSample) JSON payload.
  static const version = 1;

  /// Keys used in a map to store all the MPChart Entries we construct to be plotted.
  static const capacityValueKey = 'capacityValue';
  static const usedValueKey = 'usedValue';
  static const externalValueKey = 'externalValue';
  static const rssValueKey = 'rssValue';
  static const rasterLayerValueKey = 'rasterLayerValue';
  static const rasterPictureValueKey = 'rasterPictureValue';

  /// Keys used in a map to store all the MPEngineChart Entries we construct to be plotted,
  /// ADB memory info.
  static const javaHeapValueKey = 'javaHeapValue';
  static const nativeHeapValueKey = 'nativeHeapValue';
  static const codeValueKey = 'codeValue';
  static const stackValueKey = 'stackValue';
  static const graphicsValueKey = 'graphicsValue';
  static const otherValueKey = 'otherValue';
  static const systemValueKey = 'systemValue';
  static const totalValueKey = 'totalValue';

  static const gcUserEventKey = 'gcUserEvent';
  static const gcVmEventKey = 'gcVmEvent';
  static const snapshotEventKey = 'snapshotEvent';
  static const snapshotAutoEventKey = 'snapshotAutoEvent';
  static const monitorStartEventKey = 'monitorStartEvent';
  static const monitorContinuesEventKey = 'monitorContinuesEvent';
  static const monitorResetEventKey = 'monitorResetEvent';

  static const delayMs = 500;
  static const Duration updateDelay = Duration(milliseconds: delayMs);

  final ValueListenable<bool> offline;

  /// Return the data payload that is active.
  List<HeapSample> get data => offline.value ? offlineData : liveData;

  int get startingIndex =>
      offline.value ? offlineStartingIndex : liveStartingIndex;

  set startingIndex(int value) {
    offline.value ? offlineStartingIndex = value : liveStartingIndex = value;
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

  ContinuesState monitorContinuesState = ContinuesState.none;

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

  void addMonitorStartEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    postEventSample(
      EventSample.accumulatorStart(
        timestamp,
        events: extensionEvents,
      ),
    );
  }

  void addMonitorResetEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // TODO(terry): Enable to make continuous events visible?
    // displayContinousEvents();

    postEventSample(
      EventSample.accumulatorReset(
        timestamp,
        events: extensionEvents,
      ),
    );
  }

  void displayContinousEvents() {
    for (var index = liveData.length - 1; index >= 0; index--) {
      final sample = liveData[index];
      if (sample.memoryEventInfo.isEventAllocationAccumulator) {
        final allocationAccumulator =
            sample.memoryEventInfo.allocationAccumulator!;
        if (allocationAccumulator.isReset || allocationAccumulator.isStart) {
          for (var flipIndex = index + 1;
              flipIndex < liveData.length;
              flipIndex++) {
            final continuousEvent = liveData[flipIndex];
            assert(
              continuousEvent
                  .memoryEventInfo.allocationAccumulator!.isContinues,
            );
            continuousEvent
                .memoryEventInfo.allocationAccumulator!.continuesVisible = true;
          }
        }
      }
    }
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

  /// Notifies that the timeline has been paused.
  final _pausedNotifier = ValueNotifier<bool>(false);

  ValueNotifier<bool> get pausedNotifier => _pausedNotifier;

  void pause({bool manual = false}) {
    manuallyPaused = manual;
    _pausedNotifier.value = true;
  }

  void resume() {
    manuallyPaused = false;
    _pausedNotifier.value = false;
  }

  /// Notifies any visible marker for a particular chart should be hidden.
  final _markerHiddenNotifier = ValueNotifier<bool>(false);

  ValueListenable<bool> get markerHiddenNotifier => _markerHiddenNotifier;

  void hideMarkers() {
    _markerHiddenNotifier.value = !_markerHiddenNotifier.value;
  }

  void reset() {
    liveData.clear();
    startingIndex = 0;
  }

  /// Y-coordinate of an Event entry to not display (the no event state).
  static const emptyEvent = -2.0; // Event (empty) to not visibly display.

  /// Event to display in the event pane (User initiated GC, snapshot,
  /// automatic snapshot, etc.)
  static const visibleEvent = 1.7;

  /// Monitor events Y axis.
  static const visibleMonitorEvent = 0.85;

  /// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
  static const visibleVmEvent = 0.2;

  /// Common utility function to handle loading of the data into the
  /// chart for either offline or live Feed.

  static final DateFormat _milliFormat = DateFormat('HH:mm:ss.SSS');

  static String fineGrainTimestampFormat(int timestamp) =>
      _milliFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  void computeStartingIndex(int displayInterval) {
    // Compute a new starting index from length - N minutes.
    final timeLastSample = data.last.timestamp;
    var dataIndex = data.length - 1;
    for (; dataIndex > 0; dataIndex--) {
      final sample = data[dataIndex];
      final timestamp = sample.timestamp;

      if ((timeLastSample - timestamp) > displayInterval) break;
    }

    startingIndex = dataIndex;

    // Debugging data - to enable remove logical not operator.
    // ignore: dead_code
    if (!true) {
      final DateFormat mFormat = DateFormat('HH:mm:ss.SSS');
      final startDT = mFormat.format(
        DateTime.fromMillisecondsSinceEpoch(
          data[startingIndex].timestamp.toInt(),
        ),
      );
      final endDT = mFormat.format(
        DateTime.fromMillisecondsSinceEpoch(
          data[endingIndex].timestamp.toInt(),
        ),
      );
      log('Recompute Time range Offline data start: $startDT, end: $endDT');
    }
  }

  void addSample(HeapSample sample) {
    // Always record the heap sample in the raw set of data (liveFeed).
    liveData.add(sample);

    // Only notify that new sample has arrived if the
    // memory source is 'Live Feed'.
    if (!offline.value) {
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
