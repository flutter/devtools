// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClassTest {
  _ClassTest(
    this.name,
    this.library, {
    required this.isCore,
    required this.isDartOrFlutter,
  });

  final String name;
  final String library;
  final bool isCore;
  final bool isDartOrFlutter;
}

final _classTests = [
  _ClassTest(
    'empty',
    '',
    isCore: true,
    isDartOrFlutter: false,
  ),
  _ClassTest(
    'non-package',
    'something',
    isCore: true,
    isDartOrFlutter: false,
  ),
  _ClassTest(
    'dart-from-snapshot',
    'dart.something',
    isCore: false,
    isDartOrFlutter: true,
  ),
  _ClassTest(
    'dart-normalized',
    'dart:something',
    isCore: false,
    isDartOrFlutter: true,
  ),
  _ClassTest(
    'flutter',
    'package:flutter/something',
    isCore: false,
    isDartOrFlutter: true,
  ),
  _ClassTest(
    'standard',
    'package:collection/something',
    isCore: false,
    isDartOrFlutter: true,
  ),
  _ClassTest(
    'non-dart-flutter',
    'package:something/something',
    isCore: false,
    isDartOrFlutter: false,
  ),
];

void main() {
  group('$HeapClassName', () {
    for (var t in _classTests) {
      test('isCore and isDartOrFlutter for ${t.name}', () {
        final theClass =
            HeapClassName.fromPath(className: 'x', library: t.library);
        expect(theClass.isPackageless, t.isCore);
        expect(theClass.isDartOrFlutter, t.isDartOrFlutter);
      });
    }
  });
}
