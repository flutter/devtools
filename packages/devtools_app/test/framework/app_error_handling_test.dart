// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/src/shared/framework/app_error_handling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';

void main() {
  test(
    'keeps the original stack without fetching source maps on the VM',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        final logged = Logger('app_error_handling').onRecord.first;
        reportError(
          'VM error',
          stack: StackTrace.fromString(
            '#0 original (package:devtools_app/original.dart:1:1)',
          ),
        );
        expect((await logged).message, contains('original.dart'));
        expect(requests, 0);
      }, () => client);
    },
  );
}
