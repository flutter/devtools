// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:path/path.dart' as path;

typedef TestDtdConnectionInfo = ({
  String? uri,
  String? secret,
  Process? dtdProcess,
});

/// Helper method to start DTD for the purpose of testing.
Future<TestDtdConnectionInfo> startDtd() async {
  const dtdConnectTimeout = Duration(seconds: 10);

  final completer = Completer<TestDtdConnectionInfo>();
  Process? dtdProcess;
  StreamSubscription? dtdStoutSubscription;

  TestDtdConnectionInfo onFailure() =>
      (uri: null, secret: null, dtdProcess: dtdProcess);

  try {
    dtdProcess = await Process.start(
      Platform.resolvedExecutable,
      ['tooling-daemon', '--machine'],
    );

    dtdStoutSubscription = dtdProcess.stdout.listen((List<int> data) {
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
          completer.complete(onFailure());
        }
      } catch (e) {
        completer.complete(onFailure());
      }
    });

    return completer.future
        .timeout(dtdConnectTimeout, onTimeout: onFailure)
        .then((value) async {
      await dtdStoutSubscription?.cancel();
      return value;
    });
  } catch (e) {
    await dtdStoutSubscription?.cancel();
    return onFailure();
  }
}

class TestDartApp {
  static final dartVMServiceRegExp = RegExp(
    r'The Dart VM service is listening on (http://127.0.0.1:.*)',
  );

  final directory = Directory('tmp/test_app');

  Process? process;

  Future<String> start() async {
    await _initTestApp();
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
    await _deleteTestAppDirectory();
  }

  Future<void> _initTestApp() async {
    await _deleteTestAppDirectory();
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

  /// Deletes the directory that contains the test app.
  ///
  /// Deletes will be retried if they fail for a period to avoid failing due to
  /// Windows being slow to unlock files after processes terminate.
  Future<void> _deleteTestAppDirectory() async {
    // On Windows, trying to delete the test directory immediately after the
    // test completes may fail with a file locking error. To avoid this, retry
    // the delete a few times before failing.
    //
    // On DanTup's Windows PC, it can take ~5s for the delete to work sometimes
    // and this will probably be slower on bots. Allow a reasonable time because
    // taking 10s to delete is better than failing the tests for a non-bug.
    await runWithRetry(
      callback: () => directory.deleteSync(recursive: true),
      maxRetries: 20,
      retryDelay: const Duration(milliseconds: 500),
      stopCondition: () => !directory.existsSync(),
      onRetry: (attempt) =>
          // ignore: avoid_print, deliberate print to monitor delete failures
          print('Failed to delete test app on attempt $attempt, will retry...'),
    );
  }
}
