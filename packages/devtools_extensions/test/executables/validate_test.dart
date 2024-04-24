// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final examplesWithExtensions = [
    (
      relativePublishLocation: p.join(
        '..',
        'dart_foo',
      ),
      sourceCodeLocation: p.join(
        'example',
        'packages_with_extensions',
        'dart_foo',
        'packages',
        'dart_foo_devtools_extension',
      ),
    ),
    (
      relativePublishLocation: p.join(
        '..',
        'foo',
      ),
      sourceCodeLocation: p.join(
        'example',
        'packages_with_extensions',
        'foo',
        'packages',
        'foo_devtools_extension',
      ),
    ),
  ];

  group('devtools_extensions validate command succeeds', () {
    for (final example in examplesWithExtensions) {
      test(example.relativePublishLocation, () async {
        final p = await Process.run(
          Platform.resolvedExecutable,
          [
            'run',
            'devtools_extensions',
            'validate',
            '-p',
            example.relativePublishLocation,
          ],
          workingDirectory: example.sourceCodeLocation,
        );
        expect(p.stderr, isEmpty);
      });
    }
  });
}
