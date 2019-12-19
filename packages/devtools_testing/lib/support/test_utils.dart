// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:devtools_app/src/timeline/timeline_model.dart';

SyncTimelineEvent testSyncTimelineEvent(TraceEventWrapper eventWrapper) =>
    SyncTimelineEvent(eventWrapper);

TraceEvent testTraceEvent(Map<String, dynamic> toEncode) =>
    json.decodeTraceEvent(jsonEncode(toEncode));

int _testTimeReceived = 0;
TraceEventWrapper testTraceEventWrapper(Map<String, dynamic> toEncode) {
  return TraceEventWrapper(testTraceEvent(toEncode), _testTimeReceived++);
}
