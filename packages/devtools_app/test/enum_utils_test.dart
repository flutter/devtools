// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final colorUtils = EnumUtils<Color>(Color.values);

  test('getEnum', () {
    expect(colorUtils.enumEntry('red'), Color.red);
    expect(colorUtils.enumEntry('green'), Color.green);
    expect(colorUtils.enumEntry('blue'), Color.blue);
    expect(colorUtils.enumEntry('yellow'), null);
  });

  test('getName', () {
    expect(colorUtils.name(Color.red), 'red');
    expect(colorUtils.name(Color.green), 'green');
    expect(colorUtils.name(Color.blue), 'blue');
  });
}
