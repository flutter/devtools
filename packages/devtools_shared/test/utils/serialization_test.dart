// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/src/utils/serialization.dart';
import 'package:test/test.dart';

void main() {
  test('deserialize works for json', () {
    final json = {'key': 'value'};
    String deserializer(Map<String, dynamic> json) => 'correct';
    expect(deserialize<String>(json, deserializer), 'correct');
  });

  test('deserialize works for object', () {
    const json = 'correct';
    String deserializer(Map<String, dynamic> json) => 'wrong';
    expect(deserialize<String>(json, deserializer), 'correct');
  });
}
