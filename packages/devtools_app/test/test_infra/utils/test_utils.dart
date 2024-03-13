// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// Creates a [FlutterTimelineEvent] for testing that mocks the
/// contained [PerfettoTrackEvents].
FlutterTimelineEvent testTimelineEvent({
  required String name,
  required TimelineEventType type,
  required int startMicros,
  required int endMicros,
  required Map<String, Object?> args,
  required Map<String, Object?> endArgs,
}) {
  final mockFirstTrackEvent = MockPerfettoTrackEvent();
  when(mockFirstTrackEvent.name).thenReturn(name);
  when(mockFirstTrackEvent.timelineEventType).thenReturn(type);
  when(mockFirstTrackEvent.args).thenReturn(args);
  when(mockFirstTrackEvent.timestampMicros).thenReturn(startMicros);
  final frameNumberAsString =
      args[PerfettoTrackEvent.frameNumberArg] as String?;
  final frameNumber =
      frameNumberAsString != null ? int.tryParse(frameNumberAsString) : null;
  when(mockFirstTrackEvent.flutterFrameNumber).thenReturn(frameNumber);
  final devToolsTag = args[PerfettoTrackEvent.devtoolsTagArg] as String?;
  final isShaderEvent = devToolsTag == PerfettoTrackEvent.shadersArg;
  when(mockFirstTrackEvent.isShaderEvent).thenReturn(isShaderEvent);

  final mockEndTrackEvent = MockPerfettoTrackEvent();
  when(mockEndTrackEvent.timelineEventType).thenReturn(type);
  when(mockEndTrackEvent.args).thenReturn(endArgs);
  when(mockEndTrackEvent.timestampMicros).thenReturn(endMicros);

  return FlutterTimelineEvent(mockFirstTrackEvent)
    ..addEndTrackEvent(mockEndTrackEvent);
}

/// Overrides the system's clipboard behaviour so that strings sent to the
/// clipboard are instead passed to [clipboardContentsCallback]
///
/// [clipboardContentsCallback]  when Clipboard.setData is triggered, the text
/// contents will be passed to [clipboardContentsCallback]
void setupClipboardCopyListener({
  required void Function(String?) clipboardContentsCallback,
}) {
  // This intercepts the Clipboard.setData SystemChannel message,
  // and stores the contents that were (attempted) to be copied.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardContentsCallback((call.arguments as Map)['text']);
          break;
        case 'Clipboard.getData':
          return Future.value(<String, Object?>{});
        case 'Clipboard.hasStrings':
          return Future.value(<String, Object?>{'value': true});
        default:
          break;
      }

      return Future.value(true);
    },
  );
}

Future<String> loadPageHtmlContent(String url) async {
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();

  final completer = Completer<String>();
  final content = StringBuffer();
  response.transform(utf8.decoder).listen(
    (data) {
      content.write(data);
    },
    onDone: () => completer.complete(content.toString()),
  );
  await completer.future;
  return content.toString();
}

void setCharacterWidthForTables() {
  // Modify the character width that will be used to calculate column sizes
  // in the tree table. The flutter_tester device uses a redacted font.
  setAssumedMonospaceCharacterWidth(16.0);
}

T getWidgetFromFinder<T>(Finder finder) =>
    finder.first.evaluate().first.widget as T;
