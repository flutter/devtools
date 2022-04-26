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

  static const frameNumberArg = 'frame_number';

  /// The original event JSON.
  final Map<String, dynamic> json;

  /// The name of the event.
  ///
  /// Corresponds to the "name" field in the JSON event.
  final String? name;

  /// Event category. Events with different names may share the same category.
  ///
  /// Corresponds to the "cat" field in the JSON event.
  final String? category;

  /// For a given long lasting event, denotes the phase of the event, such as
  /// "B" for "event began", and "E" for "event ended".
  ///
  /// Corresponds to the "ph" field in the JSON event.
  final String? phase;

  /// ID of process that emitted the event.
  ///
  /// Corresponds to the "pid" field in the JSON event.
  final int? processId;

  /// ID of thread that issues the event.
  ///
  /// Corresponds to the "tid" field in the JSON event.
  final int? threadId;

  /// Each async event has an additional required parameter id. We consider the
  /// events with the same category and id as events from the same event tree.
  dynamic get id => json[idKey];

  /// An optional scope string can be specified to avoid id conflicts, in which
  /// case we consider events with the same category, scope, and id as events
  /// from the same event tree.
  String? get scope => json[scopeKey];

  /// The duration of the event, in microseconds.
  ///
  /// Note, some events are reported with duration. Others are reported as a
  /// pair of begin/end events.
  ///
  /// Corresponds to the "dur" field in the JSON event.
  final int? duration;

  /// Time passed since tracing was enabled, in microseconds.
  final int? timestampMicros;

  /// Arbitrary data attached to the event.
  final Map<String, dynamic>? args;

  String get asyncUID =>
      generateAsyncUID(id: id, category: category, scope: scope);

  TimelineEventType? _type;

  TimelineEventType get type => _type ??= TimelineEventType.other;

  set type(TimelineEventType t) => _type = t;

  bool get isUiEvent => type == TimelineEventType.ui;

  bool get isRasterEvent => type == TimelineEventType.raster;

  TraceEvent copy({
    String? name,
    String? category,
    String? phase,
    int? processId,
    int? threadId,
    int? duration,
    int? timestampMicros,
    Map<String, dynamic>? args,
  }) {
    return TraceEvent({
      nameKey: name ?? this.name,
      categoryKey: category ?? this.category,
      phaseKey: phase ?? this.phase,
      processIdKey: processId ?? this.processId,
      threadIdKey: threadId ?? this.threadId,
      durationKey: duration ?? this.duration,
      timestampKey: timestampMicros ?? this.timestampMicros,
      argsKey: args ?? this.args,
    });
  }

  @override
  String toString() => '$type event [$idKey: $id] [$phaseKey: $phase] '
      '$name - [$timestampKey: $timestampMicros] [$durationKey: $duration]';
}

int _traceEventWrapperId = 0;

class TraceEventWrapper implements Comparable<TraceEventWrapper> {
  TraceEventWrapper(this.event, this.timeReceived)
      : wrapperId = _traceEventWrapperId++;
  final TraceEvent event;

  final num timeReceived;

  final int wrapperId;

  Map<String, dynamic> get json => event.json;

  bool processed = false;

  bool get isShaderEvent => event.args!['devtoolsTag'] == 'shaders';

  @override
  int compareTo(TraceEventWrapper other) {
    // Order events based on their timestamps. If the events share a timestamp,
    // order them in the order we received them.
    final compare = (event.timestampMicros ?? 0)
        .compareTo(other.event.timestampMicros ?? 0);
    return compare != 0 ? compare : wrapperId.compareTo(other.wrapperId);
  }
}

String generateAsyncUID({
  required String? id,
  required String? category,
  String? scope,
}) {
  return [
    if (category != null) category,
    if (scope != null) scope,
    if (id != null) id,
  ].join(':');
}

enum TimelineEventType {
  ui,
  raster,
  async,
  other,
}
