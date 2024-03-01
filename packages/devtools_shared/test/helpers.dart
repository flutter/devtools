// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

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

class TestDartApp {
  static final dartVMServiceRegExp = RegExp(
    r'The Dart VM service is listening on (http://127.0.0.1:.*)',
  );

  final directory = Directory('tmp/test_app');

  Process? process;

  Future<String> start() async {
    _initTestApp();
    process = await Process.start(
      Platform.resolvedExecutable,
      ['--observe=0', 'run', 'bin/main.dart'],
      workingDirectory: directory.path,
    );

    final serviceUriCompleter = Completer<String>();
    late StreamSubscription sub;
    sub = process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
      if (line.contains(dartVMServiceRegExp)) {
        await sub.cancel();
        serviceUriCompleter.complete(
          dartVMServiceRegExp.firstMatch(line)!.group(1),
        );
      }
    });
    return await serviceUriCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () async {
        await sub.cancel();
        return '';
      },
    );
  }

  Future<void> kill() async {
    process?.kill();
    await process?.exitCode;
    process = null;
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  void _initTestApp() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    directory.createSync(recursive: true);

    final mainFile = File(path.join(directory.path, 'bin', 'main.dart'))
      ..createSync(recursive: true);
    mainFile.writeAsStringSync('''
import 'dart:async';
void main() async {
  for (int i = 0; i < 10000; i++) {
    await Future.delayed(const Duration(seconds: 2));
  }
}
''');
  }
}
