// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// Scoping method which registers `listener` as a listener for `listenable`,
/// invokes `callback`, and then removes the `listener`.
///
/// Tests that `listener` has actually been invoked.
Future<void> addListenerScope({
  @required dynamic listenable,
  @required Function listener,
  @required Function callback,
}) async {
  bool listenerCalled = false;
  final listenerWrapped = () {
    listenerCalled = true;
    listener();
  };

  listenable.addListener(listenerWrapped);
  await callback();
  expect(listenerCalled, true);
  listenable.removeListener(listenerWrapped);
}

/// Creates an instance of [Timeline] which contains recorded HTTP events.
Future<Timeline> loadNetworkProfileTimeline() async {
  // TODO(bkonyi): pull this JSON data into a .dart file.
  const testDataPath =
      '../devtools_testing/lib/support/http_request_timeline_test_data.json';
  final httpTestData = jsonDecode(
    await File(testDataPath).readAsString(),
  );
  return Timeline.parse(httpTestData);
}

Future delay() {
  return Future.delayed(const Duration(milliseconds: 500));
}

Future shortDelay() {
  return Future.delayed(const Duration(milliseconds: 100));
}
