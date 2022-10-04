// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SyncTimelineEvent testSyncTimelineEvent(TraceEventWrapper eventWrapper) =>
    SyncTimelineEvent(eventWrapper);

TraceEvent testTraceEvent(Map<String, dynamic> json) =>
    TraceEvent(jsonDecode(jsonEncode(json)));

int _testTimeReceived = 0;
TraceEventWrapper testTraceEventWrapper(Map<String, dynamic> json) {
  return TraceEventWrapper(testTraceEvent(json), _testTimeReceived++);
}

/// Overrides the system's clipboard behaviour so that strings sent to the
/// clipboard are instead passed to [clipboardContentsCallback]
///
/// [clipboardContentsCallback]  when Clipboard.setData is triggered, the text
/// contents will be passed to [clipboardContentsCallback]
void setupClipboardCopyListener({
  required Function(String?) clipboardContentsCallback,
}) {
  // This intercepts the Clipboard.setData SystemChannel message,
  // and stores the contents that were (attempted) to be copied.
  SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
    switch (call.method) {
      case 'Clipboard.setData':
        clipboardContentsCallback(call.arguments['text']);
        break;
      case 'Clipboard.getData':
        return Future.value(<String, dynamic>{});
      case 'Clipboard.hasStrings':
        return Future.value(<String, dynamic>{'value': true});
      default:
        break;
    }

    return Future.value(true);
  });
}
