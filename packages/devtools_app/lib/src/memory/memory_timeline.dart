// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui' as dart_ui;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';

import '../config_specific/logger/logger.dart';
import '../utils.dart';
import 'memory_controller.dart';

enum ContinuesState {
  none,
  start,
  stop,
  next,
}

/// All Raw data received from the VM and offline data loaded from a memory log file.
class MemoryTimeline {
  MemoryTimeline(this.controller);

  /// Version of timeline data (HeapSample) JSON payload.
  static const version = 1;

  /// Keys used in a map to store all the MPChart Entries we construct to be plotted.
  static const capcityValueKey = 'capacityValue';
  static const usedValueKey = 'usedValue';
  static const externalValueKey = 'externalValue';
  static const rssValueKey = 'rssValue';

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

  final MemoryController controller;

  /// Flutter Framework information (Dart heaps).
  final dartChartData = MPChartData();

  /// Flutter Engine (ADB memory information).
  final androidChartData = MPEngineChartData();

  /// Memory Events (GC, snapshots, allocation reset, etc.)
  final eventsChartData = MPEventsChartData();

  /// Return the data payload that is active.
  List<HeapSample> get data => controller.offline ? offlineData : liveData;

  int get startingIndex =>
      controller.offline ? offlineStartingIndex : liveStartingIndex;

  set startingIndex(int value) {
    controller.offline
        ? offlineStartingIndex = value
        : liveStartingIndex = value;
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

  /// Notifies that a new Heap sample has been added to the timeline.
  final _sampleAddedNotifier = ValueNotifier<HeapSample>(null);

  ValueListenable<HeapSample> get sampleAddedNotifier => _sampleAddedNotifier;

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
    postEventSample(EventSample.snapshotEvent(
      DateTime.now().millisecondsSinceEpoch,
      snapshotAuto: auto,
    ));
  }

  void addGCEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    postEventSample(EventSample.gcEvent(timestamp));
  }

  void addMonitorStartEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    postEventSample(EventSample.accumulatorStart(timestamp));
  }

  void addMonitorResetEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // TODO(terry): Enable to make continuous events visible?
    // displayContinousEvents();

    postEventSample(EventSample.accumulatorReset(timestamp));
  }

  void displayContinousEvents() {
    for (var index = liveData.length - 1; index >= 0; index--) {
      final sample = liveData[index];
      if (sample.memoryEventInfo != null &&
          sample.memoryEventInfo.isEventAllocationAccumulator) {
        final allocationAccumulator =
            sample.memoryEventInfo.allocationAccumulator;
        if (allocationAccumulator.isReset || allocationAccumulator.isStart) {
          for (var flipIndex = index + 1;
              flipIndex < liveData.length;
              flipIndex++) {
            final continuousEvent = liveData[flipIndex];
            assert(continuousEvent
                .memoryEventInfo.allocationAccumulator.isContinues);
            continuousEvent
                .memoryEventInfo.allocationAccumulator.continuesVisible = true;
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

  /// Grab event to be posted.
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

  /// dart_ui.Image Image asset displayed for each entry plotted in a chart.
  // ignore: unused_field
  dart_ui.Image _img;

  // TODO(terry): Look at using _img for each data point (at least last N).
  static dart_ui.Image get dataPointImage => null;

  set image(dart_ui.Image img) {
    _img = img;
  }

  void reset() {
    liveData.clear();
    startingIndex = 0;
    dartChartData.reset();
    eventsChartData.reset();
    androidChartData.reset();
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
  List<Map> _processData(int index) {
    final result = <Map<String, Entry>>[];

    for (var lastIndex = index; lastIndex < data.length; lastIndex++) {
      final sample = data[lastIndex];
      final timestamp = sample.timestamp.toDouble();

      // Flutter Framework memory (Dart VM Heaps)
      final capacity = sample.capacity.toDouble();
      final used = sample.used.toDouble();
      final external = sample.external.toDouble();

      // TOOD(terry): Need to plot.
      final rss = (sample.rss ?? 0).toDouble();

      final extEntry = Entry(x: timestamp, y: external, icon: dataPointImage);
      final usedEntry =
          Entry(x: timestamp, y: used + external, icon: dataPointImage);
      final capacityEntry =
          Entry(x: timestamp, y: capacity, icon: dataPointImage);
      final rssEntry = Entry(x: timestamp, y: rss, icon: dataPointImage);

      // Engine memory values (ADB Android):
      final javaHeap = sample.adbMemoryInfo.javaHeap.toDouble();
      final nativeHeap = sample.adbMemoryInfo.nativeHeap.toDouble();
      final code = sample.adbMemoryInfo.code.toDouble();
      final stack = sample.adbMemoryInfo.stack.toDouble();
      final graphics = sample.adbMemoryInfo.graphics.toDouble();
      final other = sample.adbMemoryInfo.other.toDouble();
      final system = sample.adbMemoryInfo.system.toDouble();
      final total = sample.adbMemoryInfo.total.toDouble();

      // Y position for each trace, each trace is stacked on top of each other.
      double yPosition = 0;

      yPosition += graphics;
      final graphicsEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += stack;
      final stackEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += javaHeap;
      final javaHeapEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += nativeHeap;
      final nativeHeapEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += code;
      final codeEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += other;
      final otherEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      yPosition += system;
      final systemEntry = Entry(
        x: timestamp,
        y: yPosition,
        icon: dataPointImage,
      );

      final totalEntry = Entry(
        x: timestamp,
        y: total,
        icon: dataPointImage,
      );

      // User initiated GC or a GC has occurred in the VM.
      final isUserGcEvent = sample.memoryEventInfo.isEventGC;
      final isSnapshotEvent = sample.memoryEventInfo.isEventSnapshot;
      final isSnapshotAutoEvent = sample.memoryEventInfo.isEventSnapshotAuto;

      final gcUserEntry = Entry(
        x: timestamp,
        y: isUserGcEvent ? visibleEvent : emptyEvent,
      );
      final gcVmEntry = Entry(
        x: timestamp,
        y: sample.isGC ? visibleVmEvent : emptyEvent,
      );
      final snapshotEntry = Entry(
        x: timestamp,
        y: isSnapshotEvent ? visibleEvent : emptyEvent,
      );
      final snapshotAutoEntry = Entry(
        x: timestamp,
        y: isSnapshotAutoEvent ? visibleEvent : emptyEvent,
      );

      final monitoring = sample.memoryEventInfo.allocationAccumulator;
      final monitorStart = monitoring != null && monitoring.isStart;
      final monitorContinues = monitoring != null && monitoring.isContinues;

      final monitorReset = monitoring != null && monitoring.isReset;

      final monitorStartEntry = Entry(
        x: timestamp,
        y: monitorStart ? visibleMonitorEvent : emptyEvent,
      );
      final monitorY = monitorContinues && monitoring.isContinuesVisible
          ? visibleMonitorEvent
          : emptyEvent;
      // TODO(terry): Consider contiuous event marker in pane between the
      //              monitorStart and monitorReset? Use monitorY of:
      //    monitorContinuesState == ContinuesState.next && !monitorStart
      //        ? visibleMonitorEvent
      //        : emptyEvent;
      final monitorContinuesEntry = Entry(
        x: timestamp,
        y: monitorY,
      );
      final monitorResetEntry = Entry(
        x: timestamp,
        y: monitorReset ? visibleMonitorEvent : emptyEvent,
      );

      final args = {
        capcityValueKey: capacityEntry,
        usedValueKey: usedEntry,
        externalValueKey: extEntry,
        rssValueKey: rssEntry,
        javaHeapValueKey: javaHeapEntry,
        nativeHeapValueKey: nativeHeapEntry,
        codeValueKey: codeEntry,
        stackValueKey: stackEntry,
        graphicsValueKey: graphicsEntry,
        otherValueKey: otherEntry,
        systemValueKey: systemEntry,
        totalValueKey: totalEntry,
        gcUserEventKey: gcUserEntry,
        gcVmEventKey: gcVmEntry,
        snapshotEventKey: snapshotEntry,
        snapshotAutoEventKey: snapshotAutoEntry,
        monitorStartEventKey: monitorStartEntry,
        monitorContinuesEventKey: monitorContinuesEntry,
        monitorResetEventKey: monitorResetEntry,
      };

      result.add(args);
    }

    return result;
  }

  /// Fetch all the data in the loaded from a memory log (JSON file in /tmp).
  List<Map> fetchMemoryLogFileData() {
    assert(controller.offline);
    assert(offlineData.isNotEmpty);
    return _processData(startingIndex);
  }

  static final DateFormat _milliFormat = DateFormat('hh:mm:ss.mmm');

  static String fineGrainTimestampFormat(int timestamp) =>
      _milliFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  List<Map> fetchLiveData([bool reloadAllData = false]) {
    assert(!controller.offline);
    assert(liveData.isNotEmpty);

    if (endingIndex - startingIndex != liveData.length || reloadAllData) {
      // Process the data received (startingDataIndex is the last sample).
      final args = _processData(endingIndex < 0 ? 0 : endingIndex);

      // Debugging data - to enable remove logical not operator.
      if (!true) {
        log('Time range Live data '
            'start: ${fineGrainTimestampFormat(liveData[startingIndex].timestamp.toInt())}, '
            'end: ${fineGrainTimestampFormat(liveData[endingIndex].timestamp.toInt())}');
      }

      return args;
    }

    return [];
  }

  List<Map> recomputeData(int displayInterval) {
    assert(displayInterval > 0);

    _computeStartingIndex(displayInterval);

    // Start from the first sample to display in this time interval.
    return _processData(startingIndex);
  }

  void _computeStartingIndex(int displayInterval) {
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
    if (!true) {
      final DateFormat mFormat = DateFormat('hh:mm:ss.mmm');
      final startDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
          data[startingIndex].timestamp.toInt()));
      final endDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
          data[endingIndex].timestamp.toInt()));
      log('Recompute Time range Offline data start: $startDT, end: $endDT');
    }
  }

  void addSample(HeapSample sample) {
    // Always record the heap sample in the raw set of data (liveFeed).
    liveData.add(sample);

    // Only notify that new sample has arrived if the
    // memory source is 'Live Feed'.
    if (!controller.offline) {
      _sampleAddedNotifier.value = sample;
      sampleEventNotifier.value++;
    }
  }
}
