// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../auto_dispose.dart';
import '../globals.dart';
import '../vm_service_wrapper.dart';

class TimelineStreamManager extends Disposer {
  static const dartTimelineStream = 'Dart';
  static const embedderTimelineStream = 'Embedder';
  static const gcTimelineStream = 'GC';
  static const apiTimelineStream = 'API';
  static const compilerTimelineStream = 'Compiler';
  static const compilerVerboseTimelineStream = 'CompilerVerbose';
  static const debuggerTimelineStream = 'Debugger';
  static const isolateTimelineStream = 'Isolate';
  static const vmTimelineStream = 'VM';

  final _advancedStreams = <String>{
    apiTimelineStream,
    compilerTimelineStream,
    compilerVerboseTimelineStream,
    debuggerTimelineStream,
    isolateTimelineStream,
    vmTimelineStream,
  };

  final _streamDescriptions = <String, String>{
    dartTimelineStream:
        'Events emitted from dart:developer Timeline APIs (including'
            ' Flutter framework events)',
    embedderTimelineStream:
        'Additional platform events (often emitted from the Flutter engine)',
    gcTimelineStream: 'Garbage collection',
    apiTimelineStream: 'Calls to the VM embedding API',
    compilerTimelineStream:
        'Compiler phases (loading code, compilation, optimization,'
            ' etc.)',
    compilerVerboseTimelineStream: 'More detailed compiler phases',
    debuggerTimelineStream: 'Debugger paused events',
    isolateTimelineStream:
        'Isolate events (startup, shutdown, snapshot loading, etc.)',
    vmTimelineStream:
        'Dart VM events (startup, shutdown, snapshot loading, etc.)',
  };

  VmServiceWrapper get service => _service;
  VmServiceWrapper _service;

  final _streams = <String, TimelineStream>{};

  List<TimelineStream> get basicStreams =>
      _streams.values.where((stream) => !stream.advanced).toList();

  List<TimelineStream> get advancedStreams =>
      _streams.values.where((stream) => stream.advanced).toList();

  ValueListenable<bool> timelineStreamListenable(String name) {
    return _streams.containsKey(name) ? _streams[name].recorded : null;
  }

  /// Initializes stream values from the vm service as a source of truth.
  Future<void> _initStreams() async {
    final timelineFlags = await service.getVMTimelineFlags();
    _streams
      ..clear()
      ..addEntries(
        [
          for (final streamName in timelineFlags.availableStreams)
            MapEntry(
              streamName,
              TimelineStream(
                name: streamName,
                description: _streamDescriptions[streamName] ?? '',
                advanced: _advancedStreams.contains(streamName),
                recorded: timelineFlags.recordedStreams.contains(streamName),
              ),
            ),
        ],
      );
    if (_streams.isEmpty) return;
  }

  /// Handles events from the VM service 'TimelineEvent' stream to track updates
  /// for recorded timeline streams.
  ///
  /// This method is responsible for updating the value of
  /// [TimelineStream.recorded] for each stream to match the value on the VM.
  @visibleForTesting
  void handleTimelineEvent(Event event) async {
    if (event.kind == EventKind.kTimelineStreamSubscriptionsUpdate) {
      final newRecordedStreams = event.updatedStreams;
      for (final stream in _streams.values) {
        stream._toggle(newRecordedStreams.contains(stream.name));
        newRecordedStreams.remove(stream.name);
      }
      if (newRecordedStreams.isNotEmpty) {
        // A new stream became available that we were not aware of.
        for (final unknownStream in newRecordedStreams) {
          _streams[unknownStream] = TimelineStream(
            name: unknownStream,
            description: _streamDescriptions[unknownStream] ?? '',
            // If we don't know about this stream, assume it is advanced.
            advanced: true,
            recorded: true,
          );
        }
      }
    }
  }

  Future<void> vmServiceOpened(VmServiceWrapper service) async {
    cancel();
    _service = service;
    // Upon setting the vm service, get initial values for vm flags.
    await _initStreams();

    autoDispose(service.onTimelineEvent.listen(handleTimelineEvent));
  }

  void vmServiceClosed() {
    _streams.clear();
    _service = null;
  }

  Future<void> setDefaultTimelineStreams() async {
    await serviceManager.service.setVMTimelineFlags([
      dartTimelineStream,
      embedderTimelineStream,
      gcTimelineStream,
    ]);
  }

  /// Sends an update to the VM service that the new recorded value for [stream]
  /// should match [value].
  Future<void> updateTimelineStream(TimelineStream stream, bool value) async {
    final recordedStreamNames = _streams.keys
        .where((streamName) => _streams[streamName].recorded.value)
        .toList();
    final alreadyBeingRecorded = recordedStreamNames.contains(stream.name);
    if (alreadyBeingRecorded && !value) {
      recordedStreamNames.remove(stream.name);
    } else if (!alreadyBeingRecorded && value) {
      recordedStreamNames.add(stream.name);
    }
    await serviceManager.service.setVMTimelineFlags(recordedStreamNames);
  }
}

class TimelineStream {
  TimelineStream({
    @required this.name,
    @required this.description,
    @required this.advanced,
    bool recorded,
  }) : _recorded = ValueNotifier<bool>(recorded);

  final String name;

  final String description;

  final bool advanced;

  ValueListenable<bool> get recorded => _recorded;
  final ValueNotifier<bool> _recorded;

  void _toggle(bool value) {
    _recorded.value = value;
  }
}
