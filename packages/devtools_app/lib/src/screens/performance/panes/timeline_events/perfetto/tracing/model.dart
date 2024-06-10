// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service_protos/vm_service_protos.dart';

import '../../../../performance_model.dart';

/// A change notifer that contains a Perfetto trace binary object [Uint8List].
///
/// We use this custom change notifier instead of a raw
/// ValueNotifier<Uint8List?> so that listeners are notified when the content of
/// the [Uint8List] changes, even if the [Uint8List] object does not change.
class PerfettoTrace extends ChangeNotifier {
  PerfettoTrace(Uint8List? traceBinary) : _traceBinary = traceBinary;

  Uint8List? get traceBinary => _traceBinary;
  Uint8List? _traceBinary;

  /// Sets the value of [_traceBinary] and notifies listeners.
  ///
  /// Listeners will be notified event if [_traceBinary] and [value] satisfy
  /// Object equality. This is intentional, since the content in the [Uint8List]
  /// may be different.
  set trace(Uint8List? value) {
    _traceBinary = value;
    notifyListeners();
  }
}

/// A data class to represent a [TrackDescriptor] event received a perfetto
/// [Trace].
class PerfettoTrackDescriptorEvent extends _PerfettoTracePacket {
  PerfettoTrackDescriptorEvent(this.trackDescriptor) : super();

  final TrackDescriptor trackDescriptor;

  String get name => trackDescriptor.name.isNotEmpty
      ? trackDescriptor.name
      : trackDescriptor.thread.threadName;

  Int64 get id => trackDescriptor.uuid;

  @override
  bool operator ==(Object other) {
    return other is PerfettoTrackDescriptorEvent &&
        other.name == name &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(name, id);
}

/// A data class to represent a [TrackEvent] event received a perfetto [Trace].
class PerfettoTrackEvent extends _PerfettoTracePacket
    implements Comparable<PerfettoTrackEvent> {
  PerfettoTrackEvent._(this.event, this.timestampMicros) : super();

  factory PerfettoTrackEvent.fromPacket(TracePacket tracePacket) {
    assert(tracePacket.hasTrackEvent());
    // [tracePacket.timestamp] is the timestamp value in nanoseconds, so we
    // divide by 1000 to get the value in microseconds. Even though
    // [trace.timestamp] is an [Int64], it is still safe to call `toInt()`
    // here because 2^52 (max JavaScript integer) nanoseconds would be
    // around 100 days, so it is improbable for protos sent by the VM
    // Service to contain values larger than 2^52 nanoseconds.
    final timestampMicros = tracePacket.timestamp.toInt() ~/ 1000;
    return PerfettoTrackEvent._(tracePacket.trackEvent, timestampMicros);
  }

  static const devtoolsTagArg = 'devtoolsTag';
  static const frameNumberArg = 'frame_number';
  static const shadersArg = 'shaders';

  /// The raw [TrackEvent] data from a Perfetto trace.
  final TrackEvent event;

  /// The timestamp in microseconds of the [TracePacket] that this event was
  /// received in.
  final int timestampMicros;

  String get name => event.name;

  late final Map<String, Object?> args = Map<String, Object?>.fromEntries(
    <MapEntry<String, Object?>?>[
      ...event.debugAnnotations.map((a) {
        final hasStringValue = a.hasStringValue();
        if (hasStringValue || a.hasLegacyJsonValue()) {
          return MapEntry(
            a.name,
            hasStringValue ? a.stringValue : a.legacyJsonValue,
          );
        }
        return null;
      }),
    ].nonNulls,
  );

  List<String> get categories => event.categories;

  /// The id of the Perfetto track that this event is included in.
  Int64 get trackId => event.trackUuid;

  /// Describes the type of this track event as defined by the Perfetto tracing
  /// API (slice begin, slice end, or instant).
  PerfettoEventType? get type => PerfettoEventType.from(event.type);

  /// The inferred [TimelineEventType] for this track event, as defined by
  /// values that are relevant for Flutter timeline events in DevTools
  /// (ui, raster, or other).
  ///
  /// For non-Flutter apps, this will always be inferred as
  /// [TimelineEventType.other].
  TimelineEventType? timelineEventType;

  /// Returns the flutter frame number for this track event, or null if it does
  /// not exist.
  int? get flutterFrameNumber {
    final frameNumber = args[frameNumberArg] as String?;
    if (frameNumber == null) return null;
    return int.tryParse(frameNumber);
  }

  /// Whether this track event is contains the flutter frame identifier for the
  /// UI track in its arguments.
  bool get isUiFrameIdentifier =>
      flutterFrameNumber != null && name == FlutterTimelineEvent.uiEventName;

  /// Whether this track event contains the flutter frame identifier for the
  /// Raster track in its arguments.
  bool get isRasterFrameIdentifier =>
      flutterFrameNumber != null &&
      name == FlutterTimelineEvent.rasterEventName;

  // Whether this track event is related to Shader compilation.
  bool get isShaderEvent => args[devtoolsTagArg] == shadersArg;

  @override
  int compareTo(PerfettoTrackEvent other) {
    // Order events based on their timestamps. If the events share a timestamp,
    // order them in the order we received them.
    final compare = timestampMicros.compareTo(other.timestampMicros);
    return compare != 0 ? compare : _creationId.compareTo(other._creationId);
  }

  @override
  String toString() =>
      '[name: $name, ts: $timestampMicros, trackId: $trackId, type: $type]';
}

/// A shared subclass for events received in a Perfetto [Trace].
///
/// This class manages creating a [_creationId] for each event, which will be
/// used to break a tie in sorting algorithms.
abstract class _PerfettoTracePacket {
  _PerfettoTracePacket() : _creationId = _tracePacketCreationId++;

  /// Creation id counter that will be incremented for each call to the
  /// [_PerfettoTracePacket] constructor.
  static int _tracePacketCreationId = 0;

  /// Creation id for a single [_PerfettoTracePacket] object.
  final int _creationId;
}

enum PerfettoEventType {
  sliceBegin('TYPE_SLICE_BEGIN'),
  sliceEnd('TYPE_SLICE_END'),
  instant('TYPE_INSTANT');

  const PerfettoEventType(this._protoName);

  static PerfettoEventType? from(TrackEvent_Type trackEventType) {
    return PerfettoEventType.values.firstWhereOrNull(
      (element) => element._protoName == trackEventType.name,
    );
  }

  final String _protoName;
}
