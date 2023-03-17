// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/primitives/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

enum Color { red, green, blue }

void main() {
  final colorUtils = EnumUtils<Color>(Color.values);

  test('enumEntry', () {
    expect(colorUtils.enumEntry('red'), Color.red);
    expect(colorUtils.enumEntry('green'), Color.green);
    expect(colorUtils.enumEntry('blue'), Color.blue);
    expect(colorUtils.enumEntry('yellow'), null);
    expect(colorUtils.enumEntry(null), null);
  });

  test('name', () {
    expect(colorUtils.name(Color.red), 'red');
    expect(colorUtils.name(Color.green), 'green');
    expect(colorUtils.name(Color.blue), 'blue');
  });

  test('enum index ordering mixin', () {
    expect(Size.xs < Size.s, isTrue);
    expect(Size.xs <= Size.s, isTrue);
    expect(Size.xs > Size.s, isFalse);
    expect(Size.xs >= Size.s, isFalse);

    expect(Size.xl < Size.m, isFalse);
    expect(Size.xl <= Size.m, isFalse);
    expect(Size.xl > Size.m, isTrue);
    expect(Size.xl >= Size.m, isTrue);
  });
}

enum Size with EnumIndexOrdering {
  xs,
  s,
  m,
  xl,
}
