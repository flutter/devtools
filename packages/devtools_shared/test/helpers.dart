// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef TestDtdConnectionInfo = ({
  String? uri,
  String? secret,
  Process? dtdProcess,
});

/// Helper method to start DTD for the purpose of testing.
Future<TestDtdConnectionInfo> startDtd() async {
  final completer =
      Completer<({String? uri, String? secret, Process? dtdProcess})>();
  Process? dtdProcess;
  try {
    dtdProcess = await Process.start(
      Platform.resolvedExecutable,
      ['tooling-daemon', '--machine'],
    );
    dtdProcess.stdout.listen((List<int> data) {
      try {
        final decoded = utf8.decode(data);
        final json = jsonDecode(decoded) as Map<String, Object?>;
        if (json
            case {
              'tooling_daemon_details': {
                'uri': final String uri,
                'trusted_client_secret': final String secret,
              }
            }) {
          completer.complete(
            (uri: uri, secret: secret, dtdProcess: dtdProcess),
          );
        } else {
          completer.complete((uri: null, secret: null, dtdProcess: dtdProcess));
        }
      } catch (e) {
        completer.complete((uri: null, secret: null, dtdProcess: dtdProcess));
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => (uri: null, secret: null, dtdProcess: dtdProcess),
    );
  } catch (e) {
    return (uri: null, secret: null, dtdProcess: dtdProcess);
  }
}
