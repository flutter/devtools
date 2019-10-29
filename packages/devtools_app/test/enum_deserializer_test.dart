// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/enum_deserializer.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final deserializer = EnumDeserializer<Color>(Color.values);

  test('deserialize return null', () {
    expect(deserializer.deserialize('red'), Color.red);
    expect(deserializer.deserialize('green'), Color.green);
    expect(deserializer.deserialize('blue'), Color.blue);
  });

  test('deserialize return correct enum', () {
    expect(deserializer.deserialize('yellow'), null);
  });
}
