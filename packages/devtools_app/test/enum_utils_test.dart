// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final deserializer = EnumUtils<Color>(Color.values);

  test('getEnum', () {
    expect(deserializer.toEnumEntry('red'), Color.red);
    expect(deserializer.toEnumEntry('green'), Color.green);
    expect(deserializer.toEnumEntry('blue'), Color.blue);
    expect(deserializer.toEnumEntry('yellow'), null);
  });

  test('getName', () {
    expect(deserializer.toName(Color.red), 'red');
    expect(deserializer.toName(Color.green), 'green');
    expect(deserializer.toName(Color.blue), 'blue');
  });
}
