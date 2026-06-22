// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:vm_service/vm_service.dart';

import '../../../test_infra/test_data/network.dart';

/// Creates a minimal [HttpProfileRequest] for use in Network View tests.
HttpProfileRequest createTestHttpRequest({
  required String id,
  required String method,
  int startTime = 2_000_000,
  String uri = 'https://example.com/test',
}) {
  final endTime = startTime + 1000;
  return HttpProfileRequest.parse({
    'type': 'HttpProfileRequest',
    'id': id,
    'isolateId': 'isolates/test',
    'method': method,
    'uri': uri,
    'events': [],
    'startTime': startTime,
    'endTime': endTime,
    'response': {
      'startTime': startTime,
      'endTime': endTime,
      'redirects': [],
      'statusCode': 200,
    },
  })!;
}

SocketProfile loadSocketProfile() {
  return SocketProfile(
    sockets: [
      SocketStatistic.parse(testSocket1Json)!,
      SocketStatistic.parse(testSocket2Json)!,
    ],
  );
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
      HttpProfileRequest.parse(httpGetPendingJson)!,
    ],
    timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
  );
}
