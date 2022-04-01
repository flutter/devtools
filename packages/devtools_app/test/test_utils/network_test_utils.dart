// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:vm_service/vm_service.dart';

import '../test_data/network_test_data.dart';

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
    timestamp: 0,
  );
}
