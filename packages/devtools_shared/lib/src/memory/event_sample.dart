// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../utils/serialization.dart';

/// Monitor heap object allocations (in the VM).
///
/// The allocation monitor will cause 'start' event exist in the `HeapSample`.
/// Immediately afterwards a 'continues' event is added on each
/// subsequent timestamp tick (`HeapSample`) until another monitor start event.
/// A 'reset' event stops the 'continues' event for one timestamp tick
/// with a 'reset' event. Immediately after the reset event a 'continues' event
/// will again appear in the HeapSample's `MemoryEventInfo` - until
/// a new monitor is started. One monitor exists per VM connection.
class AllocationAccumulator {
  AllocationAccumulator(this._start, this._continues, this._reset);

  AllocationAccumulator.start()
      : _start = true,
        _continues = false,
        _reset = false;
  AllocationAccumulator.continues()
      : _start = false,
        _continues = true,
        _reset = false;
  AllocationAccumulator.reset()
      : _start = false,
        _continues = false,
        _reset = true;

  factory AllocationAccumulator.fromJson(Map<String, Object?> json) =>
      AllocationAccumulator(
        json['start'] as bool,
        json['continues'] as bool,
        json['reset'] as bool,
      );

  Map<String, dynamic> toJson() => <String, Object?>{
        'start': _start,
        'continues': _continues,
        'reset': _reset,
      };

  static AllocationAccumulator empty() =>
      AllocationAccumulator(false, false, false);

  bool get isEmpty => !isStart && !isContinuesVisible && !isReset;

  final bool _start;

  final bool _continues;
  bool continuesVisible = false;

  final bool _reset;

  bool get isStart => _start;

  bool get isContinues => _continues;
  bool get isContinuesVisible => isContinues && continuesVisible;

  bool get isReset => _reset;

  @override
  String toString() => '[AllocationAccumulator '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}

class ExtensionEvent {
  ExtensionEvent(this.timestamp, this.eventKind, this.data)
      : customEventName = null;

  ExtensionEvent.custom(
    this.timestamp,
    this.eventKind,
    this.customEventName,
    this.data,
  );

  factory ExtensionEvent.fromJson(Map<String, Object?> json) =>
      ExtensionEvent.custom(
        json['timestamp'] as int?,
        json['eventKind'] as String?,
        json['customEventName'] as String?,
        (json['data'] as Map?)?.cast<String, Object>(),
      );

  Map<String, dynamic> toJson() => <String, Object?>{
        'timestamp': timestamp,
        'eventKind': eventKind,
        'data': data,
        'customEventName': customEventName,
      };

  static ExtensionEvent empty() =>
      ExtensionEvent.custom(null, null, null, null);

  bool get isEmpty =>
      timestamp == null &&
      eventKind == null &&
      data == null &&
      customEventName == null;

  final int? timestamp;

  final String? eventKind;

  final Map<String, Object>? data;

  final String? customEventName;

  @override
  String toString() => '[ExtensionEvent '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}

class ExtensionEvents {
  ExtensionEvents(List<ExtensionEvent> events) {
    this.events.addAll(events);
  }

  factory ExtensionEvents.fromJson(Map<String, Object> json) {
    final events = <ExtensionEvent>[];

    json.forEach((key, value) {
      final event = ExtensionEvent.fromJson(value as Map<String, Object?>);
      events.add(event);
    });

    return ExtensionEvents(events);
  }

  Map<String, dynamic> toJson() {
    final eventsAsJson = <String, Object?>{};
    var index = 0;
    for (final event in events) {
      eventsAsJson['$index'] = event.toJson();
      index++;
    }

    return eventsAsJson;
  }

  final events = <ExtensionEvent>[];

  bool get isEmpty => events.isEmpty;

  bool get isNotEmpty => events.isNotEmpty;

  void clear() => events.clear();

  @override
  String toString() => '[ExtensionEvents = '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}

class EventSample with Serializable {
  EventSample(
    this.timestamp,
    this.isEventGC,
    this.isEventSnapshot,
    this.isEventSnapshotAuto,
    this.allocationAccumulator,
    this.extensionEvents,
  );

  EventSample.gcEvent(this.timestamp, {ExtensionEvents? events})
      : isEventGC = true,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = null,
        extensionEvents = events;

  EventSample.snapshotEvent(
    this.timestamp, {
    bool snapshotAuto = false,
    ExtensionEvents? events,
  })  : isEventGC = false,
        isEventSnapshot = !snapshotAuto,
        isEventSnapshotAuto = snapshotAuto,
        allocationAccumulator = null,
        extensionEvents = events;

  EventSample.accumulatorStart(
    this.timestamp, {
    ExtensionEvents? events,
  })  : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.start(),
        extensionEvents = events;

  EventSample.accumulatorContinues(
    this.timestamp, {
    ExtensionEvents? events,
  })  : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.continues(),
        extensionEvents = events;

  EventSample.accumulatorReset(
    this.timestamp, {
    ExtensionEvents? events,
  })  : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.reset(),
        extensionEvents = events;

  EventSample.extensionEvent(this.timestamp, this.extensionEvents)
      : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = null;

  factory EventSample.fromJson(Map<String, Object?> json) {
    final extensionEvents =
        (json['extensionEvents'] as Map?)?.cast<String, Object>();

    return EventSample(
      json['timestamp'] as int,
      (json['gcEvent'] as bool?) ?? false,
      (json['snapshotEvent'] as bool?) ?? false,
      (json['snapshotAutoEvent'] as bool?) ?? false,
      json['allocationAccumulatorEvent'] != null
          ? AllocationAccumulator.fromJson(
              json['allocationAccumulatorEvent'] as Map<String, Object?>,
            )
          : null,
      extensionEvents != null
          ? ExtensionEvents.fromJson(extensionEvents)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, Object?>{
        'timestamp': timestamp,
        'gcEvent': isEventGC,
        'snapshotEvent': isEventSnapshot,
        'snapshotAutoEvent': isEventSnapshotAuto,
        'allocationAccumulatorEvent': allocationAccumulator?.toJson(),
        'extensionEvents': extensionEvents?.toJson(),
      };

  EventSample clone(int timestamp, {ExtensionEvents? extensionEvents}) =>
      EventSample(
        timestamp,
        isEventGC,
        isEventSnapshot,
        isEventSnapshotAuto,
        allocationAccumulator,
        extensionEvents,
      );

  /// Create an empty event (all values are nothing).
  static EventSample empty() => EventSample(
        -1,
        false,
        false,
        false,
        AllocationAccumulator.empty(),
        null,
      );

  bool get isEmpty => timestamp == -1;

  /// The version of the [EventSample] JSON payload.
  static const version = 1;

  final int timestamp;

  final bool isEventGC;

  final bool isEventSnapshot;

  final bool isEventSnapshotAuto;

  bool get isEventAllocationAccumulator => allocationAccumulator != null;

  bool get hasExtensionEvents => extensionEvents != null;

  final AllocationAccumulator? allocationAccumulator;

  final ExtensionEvents? extensionEvents;

  @override
  String toString() => '[EventSample timestamp: $timestamp = '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}

/// Engine's Raster Cache estimates.
class RasterCache with Serializable {
  RasterCache._({required this.layerBytes, required this.pictureBytes});

  factory RasterCache.fromJson(Map<String, Object?> json) {
    return RasterCache._(
      layerBytes: json['layerBytes'] as int,
      pictureBytes: json['pictureBytes'] as int,
    );
  }

  static RasterCache empty() => RasterCache._(layerBytes: 0, pictureBytes: 0);

  static RasterCache? parse(Map<String, Object?>? json) =>
      json == null ? null : RasterCache.fromJson(json);

  int layerBytes;

  int pictureBytes;

  @override
  Map<String, dynamic> toJson() => <String, Object?>{
        'layerBytes': layerBytes,
        'pictureBytes': pictureBytes,
      };

  @override
  String toString() => '[RasterCache '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}
