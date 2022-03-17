// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_data/http_request_timeline_test_data.dart';
import '../test_data/network_test_data.dart';

/// Creates an instance of [Timeline] which contains recorded HTTP events.
Future<Timeline> loadNetworkProfileTimeline() async {
  final httpTestData = jsonDecode(httpRequestTimelineTestData);
  return Timeline.parse(httpTestData)!;
}

SocketProfile loadSocketProfile() {
  return SocketProfile(sockets: [
    SocketStatistic.parse(testSocket1Json)!,
    SocketStatistic.parse(testSocket2Json)!,
  ]);
}

HttpProfile loadHttpProfile() {
  return HttpProfile(
    requests: [
      HttpProfileRequest.parse(httpGetJson)!,
      HttpProfileRequest.parse(httpGetWithErrorJson)!,
      HttpProfileRequest.parse(httpPostJson)!,
      HttpProfileRequest.parse(httpPutJson)!,
      HttpProfileRequest.parse(httpPatchJson)!,
      HttpProfileRequest.parse(httpWsHandshakeJson)!,
    ],
    timestamp: 0,
  );
}
