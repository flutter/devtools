// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../shared/primitives/trace_event.dart';

const debugTraceEventDuplicates = false;

/// Helper method to call a callback only when debugging issues related to trace
/// event duplicates (for example https://github.com/dart-lang/sdk/issues/46605).
void debugTraceEventCallback(VoidCallback callback) {
  if (debugTraceEventDuplicates) {
    callback();
  }
}

const preCompileShadersDocsUrl = 'https://docs.flutter.dev/perf/shader';

const impellerDocsUrl = 'https://docs.flutter.dev/perf/impeller';

extension TraceEventExtension on TraceEvent {
  bool get isThreadNameEvent =>
      phase == TraceEvent.metadataEventPhase &&
      name == TraceEvent.threadNameEvent;
}
