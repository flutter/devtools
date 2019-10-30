// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final colorUtils = EnumUtils<Color>(Color.values);

  test('getEnum', () {
    expect(colorUtils.toEnumEntry('red'), Color.red);
    expect(colorUtils.toEnumEntry('green'), Color.green);
    expect(colorUtils.toEnumEntry('blue'), Color.blue);
    expect(colorUtils.toEnumEntry('yellow'), null);
  });

  test('getName', () {
    expect(colorUtils.toName(Color.red), 'red');
    expect(colorUtils.toName(Color.green), 'green');
    expect(colorUtils.toName(Color.blue), 'blue');
  });
}
