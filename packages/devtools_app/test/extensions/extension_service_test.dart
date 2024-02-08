// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$ExtensionService', () {
    test('rootFromFileUriString', () {
      // Dart file under 'lib'
      expect(
        rootFromFileUriString('file:///Users/me/foo/my_app_root/lib/main.dart'),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/lib/sub/main.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'bin'
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/bin/script.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/bin/sub/script.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'test'
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/test/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/test/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'integration_test'
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/integration_test/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/integration_test/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'benchmark'
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/benchmark/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        rootFromFileUriString(
          'file:///Users/me/foo/my_app_root/benchmark/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
    });
  });
}
