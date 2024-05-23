// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/src/utils/serialization.dart';
import 'package:test/test.dart';

void main() {
  group('deserialize', () {
    test('works for json', () {
      final json = {'key': 'value'};
      String deserializer(Map<String, dynamic> _) => 'correct';
      expect(deserialize<String>(json, deserializer), 'correct');
    });

    test('works for object', () {
      const json = 'correct';
      String deserializer(Map<String, dynamic> _) => 'wrong';
      expect(deserialize<String>(json, deserializer), 'correct');
    });
  });

  group('deserializeNullable', () {
    test('works for json', () {
      final json = {'key': 'value'};
      String deserializer(Map<String, dynamic> _) => 'correct';
      expect(deserializeNullable<String>(json, deserializer), 'correct');
    });

    test('works for object', () {
      const json = 'correct';
      String deserializer(Map<String, dynamic> _) => 'wrong';
      expect(deserializeNullable<String>(json, deserializer), 'correct');
    });

    test('works for null', () {
      String deserializer(Map<String, dynamic> _) => 'wrong';
      expect(deserializeNullable<String>(null, deserializer), null);
    });
  });
}
