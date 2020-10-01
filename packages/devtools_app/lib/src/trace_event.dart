// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(devoncarew): Upstream this class to the service protocol library.

/// A single timeline event.
class TraceEvent {
  /// Creates a timeline event given JSON-encoded event data.
  TraceEvent(this.json)
      : name = json[nameKey],
        category = json[categoryKey],
        phase = json[phaseKey],
        processId = json[processIdKey],
        threadId = json[threadIdKey],
        duration = json[durationKey],
        timestampMicros = json[timestampKey],
        args = json[argsKey];

  static const nameKey = 'name';
  static const categoryKey = 'cat';
  static const phaseKey = 'ph';
  static const processIdKey = 'pid';
  static const threadIdKey = 'tid';
  static const durationKey = 'dur';
  static const timestampKey = 'ts';
  static const argsKey = 'args';
  static const typeKey = 'type';
  static const idKey = 'id';
  static const scopeKey = 'scope';

  static const asyncBeginPhase = 'b';
  static const asyncEndPhase = 'e';
  static const asyncInstantPhase = 'n';
  static const durationBeginPhase = 'B';
  static const durationEndPhase = 'E';
  static const durationCompletePhase = 'X';
  static const flowStartPhase = 's';
  static const flowEndPhase = 'f';

  static const gcCategory = 'GC';

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

  /// Each async event has an additional required parameter id. We consider the
  /// events with the same category and id as events from the same event tree.
  dynamic get id => json[idKey];

  /// An optional scope string can be specified to avoid id conflicts, in which
  /// case we consider events with the same category, scope, and id as events
  /// from the same event tree.
  String get scope => json[scopeKey];

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

  String get asyncUID {
    if (scope == null) {
      return '$category:$id';
    } else {
      return '$category:$scope:$id';
    }
  }

  TimelineEventType _type;

  TimelineEventType get type => _type ??= TimelineEventType.unknown;

  set type(TimelineEventType t) => _type = t;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isRasterEvent => type == TimelineEventType.raster;

  @override
  String toString() => '$type event [$idKey: $id] [$phaseKey: $phase] '
      '$name - [$timestampKey: $timestampMicros] [$durationKey: $duration]';
}

int _traceEventWrapperId = 0;

class TraceEventWrapper implements Comparable<TraceEventWrapper> {
  TraceEventWrapper(this.event, this.timeReceived)
      : id = _traceEventWrapperId++;
  final TraceEvent event;

  final num timeReceived;

  final int id;

  Map<String, dynamic> get json => event.json;

  bool processed = false;

  @override
  int compareTo(TraceEventWrapper other) {
    // Order events based on their timestamps. If the events share a timestamp,
    // order them in the order we received them.
    final compare =
        event.timestampMicros.compareTo(other.event.timestampMicros);
    return compare != 0 ? compare : id.compareTo(other.id);
  }
}

enum TimelineEventType {
  ui,
  raster,
  async,
  unknown,
}
