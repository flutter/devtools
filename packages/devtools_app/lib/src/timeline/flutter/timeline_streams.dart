// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

class RecordedTimelineStream {
  RecordedTimelineStream({
    @required this.name,
    @required this.description,
    this.advanced = false,
  });

  final String name;

  final String description;

  final bool advanced;

  ValueListenable<bool> get enabled => _enabled;

  final _enabled = ValueNotifier<bool>(false);

  void toggle(bool value) {
    _enabled.value = value;
  }

  @override
  bool operator ==(other) {
    return name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}

final dartTimelineStream = RecordedTimelineStream(
  name: 'Dart',
  description:
      'Events emitted from dart:developer Timeline APIs (including Flutter '
      'framework events)',
);

final embedderTimelineStream = RecordedTimelineStream(
  name: 'Embedder',
  description:
      'Additional platform events (often emitted from the Flutter engine)',
);

final gcTimelineStream = RecordedTimelineStream(
  name: 'GC',
  description: 'Garbage collection',
);

final apiTimelineStream = RecordedTimelineStream(
  name: 'API',
  description: 'Calls to the VM embedding API',
  advanced: true,
);

final compilerTimelineStream = RecordedTimelineStream(
  name: 'Compiler',
  description:
      'Compiler phases (loading code, compilation, optimization, etc.)',
  advanced: true,
);

final compilerVerboseTimelineStream = RecordedTimelineStream(
  name: 'CompilerVerbose',
  description: 'More detailed compiler phases',
  advanced: true,
);

final debuggerTimelineStream = RecordedTimelineStream(
  name: 'Debugger',
  description: 'Debugger paused events',
  advanced: true,
);

final isolateTimelineStream = RecordedTimelineStream(
  name: 'Isolate',
  description: 'Isolate events (startup, shutdown, snapshot loading, etc.)',
  advanced: true,
);

final vmTimelineStream = RecordedTimelineStream(
  name: 'VM',
  description: 'Dart VM events (startup, shutdown, snapshot loading, etc.)',
  advanced: true,
);
