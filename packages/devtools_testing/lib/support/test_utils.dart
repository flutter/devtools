// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/trace_event.dart';

SyncTimelineEvent testSyncTimelineEvent(TraceEventWrapper eventWrapper) =>
    SyncTimelineEvent(eventWrapper);

TraceEvent testTraceEvent(Map<String, dynamic> json) =>
    TraceEvent(jsonDecode(jsonEncode(json)));

int _testTimeReceived = 0;
TraceEventWrapper testTraceEventWrapper(Map<String, dynamic> json) {
  return TraceEventWrapper(testTraceEvent(json), _testTimeReceived++);
}
