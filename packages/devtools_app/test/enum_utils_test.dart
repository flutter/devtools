// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final deserializer = EnumUtils<Color>(Color.values);

  test('getEnum', () {
    expect(deserializer.getEnum('red'), Color.red);
    expect(deserializer.getEnum('green'), Color.green);
    expect(deserializer.getEnum('blue'), Color.blue);
    expect(deserializer.getEnum('yellow'), null);
  });

  test('getName', () {
    expect(deserializer.getName(Color.red), 'red');
    expect(deserializer.getName(Color.green), 'green');
    expect(deserializer.getName(Color.blue), 'blue');
  });
}
