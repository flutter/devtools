// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A single trace event that follows the Chrome Trace Event Format.
///
/// See Chrome Trace Event Format documentation:
/// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview
class ChromeTraceEvent {
  /// Creates a timeline event given JSON-encoded event data.
  ChromeTraceEvent(this.json)
      : name = json[nameKey] as String?,
        category = json[categoryKey] as String?,
        phase = json[phaseKey] as String?,
        processId = json[processIdKey] as int?,
        threadId = json[threadIdKey] as int?,
        duration = json[durationKey] as int?,
        timestampMicros = json[timestampKey] as int?,
        args = json[argsKey] as Map<String, Object?>?;

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
  static const metadataEventPhase = 'M';

  static const gcCategory = 'GC';

  static const frameNumberArg = 'frame_number';

  /// Event name for thread name metadata events.
  static const threadNameEvent = 'thread_name';

  /// The original event JSON.
  final Map<String, Object?> json;

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
  String? get id => json[idKey] as String?;

  /// An optional scope string can be specified to avoid id conflicts, in which
  /// case we consider events with the same category, scope, and id as events
  /// from the same event tree.
  String? get scope => json[scopeKey] as String?;

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
  final Map<String, Object?>? args;

  ChromeTraceEvent copy({
    String? name,
    String? category,
    String? phase,
    int? processId,
    int? threadId,
    int? duration,
    int? timestampMicros,
    Map<String, dynamic>? args,
  }) {
    return ChromeTraceEvent({
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
  String toString() => '[$idKey: $id] [$phaseKey: $phase] '
      '$name - [$timestampKey: $timestampMicros] [$durationKey: $duration]';
}
