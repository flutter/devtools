// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  group('file uri helpers', () {
    test('rootFromFileUriString', () {
      // Dart file under 'lib'
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/lib/main.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/lib/sub/main.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'bin'
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/bin/script.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/bin/sub/script.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'test'
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/test/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/test/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'integration_test'
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/integration_test/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/integration_test/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );

      // Dart file under 'benchmark'
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/benchmark/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
      expect(
        packageRootFromFileUriString(
          'file:///Users/me/foo/my_app_root/benchmark/sub/some_test.dart',
        ),
        equals('file:///Users/me/foo/my_app_root'),
      );
    });
  });
}
