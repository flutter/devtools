// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/src/shared/framework/app_error_handling.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';

void main() {
  test(
    'shares source maps across startup and errors, retrying failed loads',
    () async {
      final oldFlutterErrorHandler = FlutterError.onError;
      final oldPlatformErrorHandler = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = oldFlutterErrorHandler;
        PlatformDispatcher.instance.onError = oldPlatformErrorHandler;
      });

      var requests = 0;
      final successfulResponse = Completer<http.Response>();
      final sourceMap = jsonEncode({
        'version': 3,
        'file': 'main.dart.${kIsWasm ? 'wasm' : 'js'}',
        'sources': ['original.dart'],
        'names': ['originalFunction'],
        'mappings': 'AAAAA',
      });
      final client = MockClient((request) {
        expect(request.url.path, 'main.dart.${kIsWasm ? 'wasm' : 'js'}.map');
        requests++;
        switch (requests) {
          case 1:
            return Future.value(http.Response('Not found', 404));
          case 2:
            return Future.value(http.Response('invalid source map', 200));
          case 3:
            return Future.error(http.ClientException('Offline', request.url));
          default:
            return successfulResponse.future;
        }
      });

      Future<void> startApp() async {
        final started = Completer<void>();
        setupErrorHandling(() async {
          started.complete();
        });
        await started.future;
      }

      Future<LogRecord> report(String message) {
        final logged = Logger('app_error_handling').onRecord.firstWhere(
          (record) => record.message.startsWith('[source-map-test]: $message'),
        );
        reportError(
          message,
          errorType: 'source-map-test',
          stack: StackTrace.fromString(
            '    at generated (main.dart.${kIsWasm ? 'wasm' : 'js'}:1:1)',
          ),
        );
        return logged;
      }

      await http.runWithClient(() async {
        await startApp();
        expect(requests, 1);
        await report('invalid map');
        await report('offline map');
        expect(requests, 3);

        final first = report('first mapped error');
        final second = report('second mapped error');
        successfulResponse.complete(http.Response(sourceMap, 200));
        final records = await Future.wait([first, second]);
        for (final record in records) {
          expect(record.message, contains('original.dart'));
        }
        expect(
          (await report('later mapped error')).message,
          contains('original.dart'),
        );
        await startApp();
        expect(requests, 4);
      }, () => client);
    },
  );
}
