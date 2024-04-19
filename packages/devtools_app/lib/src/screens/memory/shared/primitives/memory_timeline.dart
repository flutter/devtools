// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/primitives/utils.dart';

/// All Raw data received from the VM or offline data.
class MemoryTimeline {
  MemoryTimeline();

  factory MemoryTimeline.fromJson(Map<String, dynamic> map) {
    throw UnimplementedError();
  }

  Map<String, dynamic> toJson() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  int get endingIndex => data.isNotEmpty ? data.length - 1 : -1;

  /// Raw Heap sampling data from the VM.
  final List<HeapSample> data = [];

  /// Extension Events.
  ValueListenable<Event?> get eventNotifier => _eventFiredNotifier;
  final _eventFiredNotifier = ValueNotifier<Event?>(null);

  /// Notifies that a new Heap sample has been added to the timeline.
  ValueListenable<HeapSample?> get sampleAddedNotifier => _sampleAddedNotifier;
  final _sampleAddedNotifier = ValueNotifier<HeapSample?>(null);

  /// List of events awaiting to be posted to HeapSample.
  final _eventSamples = <EventSample>[];

  bool get anyEvents => peekEventTimestamp != -1;

  /// Peek at next event to pull, if no event return -1 timestamp.
  int get peekEventTimestamp {
    final event = _eventSamples.safeFirst;
    return event != null ? event.timestamp : -1;
  }

  ValueNotifier<int> get sampleEventNotifier => _sampleEventNotifier;
  final _sampleEventNotifier = ValueNotifier<int>(0);

  ExtensionEvents? get extensionEvents {
    if (_extensionEvents.isNotEmpty) {
      final eventsToProcess = ExtensionEvents(_extensionEvents.toList());
      _extensionEvents.clear();
      return eventsToProcess;
    }
    return null;
  }

  final _extensionEvents = <ExtensionEvent>[];

  bool get anyPendingExtensionEvents => _extensionEvents.isNotEmpty;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  void reset() {
    data.clear();
  }

  static final DateFormat _milliFormat = DateFormat('HH:mm:ss.SSS');

  static String fineGrainTimestampFormat(int timestamp) =>
      _milliFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  static const customDevToolsEvent = 'DevTools.Event';
  static const devToolsExtensionEvent = '${customDevToolsEvent}_';

  static bool isCustomEvent(String extensionEvent) =>
      extensionEvent.startsWith(devToolsExtensionEvent);

  static String customEventName(String extensionEventKind) =>
      extensionEventKind.substring(
        MemoryTimeline.devToolsExtensionEvent.length,
      );

  void addSample(HeapSample sample) {
    data.add(sample);
    _sampleAddedNotifier.value = sample;
    sampleEventNotifier.value++;
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

  /// Grab and remove the event to be posted.
  EventSample pullEventSample() {
    final result = _eventSamples.first;
    _eventSamples.removeAt(0);
    return result;
  }

  void addSnapshotEvent({bool auto = false}) {
    _eventSamples.add(
      EventSample.snapshotEvent(
        DateTime.now().millisecondsSinceEpoch,
        snapshotAuto: auto,
        events: extensionEvents,
      ),
    );
  }

  void addGCEvent() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _eventSamples.add(
      EventSample.gcEvent(
        timestamp,
        events: extensionEvents,
      ),
    );
  }
}
