// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Monitor heap object allocations (in the VM).  The allocation monitor will
/// cause 'start' event exist in the HeapSample. Immediately afterwards a
/// 'continues' event is added on each subsequent timestamp tick (HeapSample)
/// until another monitor start event.  A 'reset' event stops the 'continues'
/// event for one timestamp tick with a 'reset' event. Immediately after the
/// reset event a 'continues' event will again appear in the HeapSample's
/// MemoryEventInfo - until a new monitor is started. One monitor exists per
/// VM connection.
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

  factory AllocationAccumulator.fromJson(Map<String, dynamic> json) =>
      AllocationAccumulator(
        json['start'] as bool,
        json['continues'] as bool,
        json['reset'] as bool,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
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
      'isStart: $isStart, '
      'isContinues: $isContinues, '
      'isReset: $isReset]';
}

class EventSample {
  EventSample(
    this.timestamp,
    this.isEventGC,
    this.isEventSnapshot,
    this.isEventSnapshotAuto,
    this.allocationAccumulator,
  );

  EventSample.gcEvent(this.timestamp)
      : isEventGC = true,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = null;

  EventSample.snapshotEvent(this.timestamp, {snapshotAuto = false})
      : isEventGC = false,
        isEventSnapshot = !snapshotAuto,
        isEventSnapshotAuto = snapshotAuto,
        allocationAccumulator = null;

  EventSample.accumulatorStart(this.timestamp)
      : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.start();

  EventSample.accumulatorContinues(this.timestamp)
      : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.continues();

  EventSample.accumulatorReset(this.timestamp)
      : isEventGC = false,
        isEventSnapshot = false,
        isEventSnapshotAuto = false,
        allocationAccumulator = AllocationAccumulator.reset();

  factory EventSample.fromJson(Map<String, dynamic> json) => EventSample(
        json['timestamp'] as int,
        json['gcEvent'] as bool,
        json['snapshotEvent'] as bool,
        json['snapshotAutoEvent'] as bool,
        json['allocationAccumulatorEvent'] != null
            ? AllocationAccumulator.fromJson(json['allocationAccumulatorEvent'])
            : null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp,
        'gcEvent': isEventGC,
        'snapshotEvent': isEventSnapshot,
        'snapshotAutoEvent': isEventSnapshotAuto,
        'allocationAccumulatorEvent': allocationAccumulator?.toJson(),
      };

  EventSample clone(int timestamp) => EventSample(
        timestamp,
        isEventGC,
        isEventSnapshot,
        isEventSnapshotAuto,
        allocationAccumulator,
      );

  /// Create an empty event (all values are nothing)
  static EventSample empty() => EventSample(
        -1,
        false,
        false,
        false,
        AllocationAccumulator.empty(),
      );

  bool get isEmpty => timestamp == -1;

  /// Version of EventSample JSON payload.
  static const version = 1;

  final int timestamp;

  final bool isEventGC;

  final bool isEventSnapshot;

  final bool isEventSnapshotAuto;

  bool get isEventAllocationAccumulator => allocationAccumulator != null;

  AllocationAccumulator allocationAccumulator;

  @override
  String toString() => '[EventSample timestamp: $timestamp, '
      'isEventGC: $isEventGC, '
      'isEventSnapshot: $isEventSnapshot, '
      'isEventSnapshotAuto: $isEventSnapshotAuto,'
      'allocationAccumulator: \n   $allocationAccumulator]';
}

/// Engine's Raster Cache estimates.
class RasterCache {
  RasterCache({@required this.layerBytes, @required this.pictureBytes});

  RasterCache.fromJson(Map<String, dynamic> json) {
    layerBytes = json['layerBytes'];
    pictureBytes = json['pictureBytes'];
  }

  static RasterCache empty() => RasterCache(layerBytes: 0, pictureBytes: 0);

  static RasterCache parse(Map<String, dynamic> json) =>
      json == null ? null : RasterCache.fromJson(json);

  int layerBytes;

  int pictureBytes;

  Map<String, dynamic> toJson() => {
        'layerBytes': layerBytes,
        'pictureBytes': pictureBytes,
      };

  @override
  String toString() =>
      '[RasterCache layerBytes: $layerBytes, pictureBytes: $pictureBytes]';
}
