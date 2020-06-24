// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  const Color customLight = Color.fromARGB(200, 202, 191, 69);
  const Color customDark = Color.fromARGB(100, 99, 101, 103);
  const customColor = ThemedColor(customLight, customDark);

  test('light theme', () {
    // ignore: deprecated_member_use_from_same_package
    setTheme(darkTheme: false);
    expect(defaultBackground.toColor().red, equals(255));
    expect(defaultBackground.toColor().green, equals(255));
    expect(defaultBackground.toColor().blue, equals(255));
    expect(defaultBackground.toColor().alpha, equals(255));

    expect(defaultForeground.toColor().red, equals(0));
    expect(defaultForeground.toColor().green, equals(0));
    expect(defaultForeground.toColor().blue, equals(0));
    expect(defaultForeground.toColor().alpha, equals(255));

    expect(customColor.toColor().value, equals(customLight.value));
    expect(customColor.toColor().alpha, equals(customLight.alpha));
    expect(customColor.toColor().red, equals(customLight.red));
    expect(customColor.toColor().green, equals(customLight.green));
    expect(customColor.toColor().blue, equals(customLight.blue));
  });

  test('dark theme', () {
    // ignore: deprecated_member_use_from_same_package
    setTheme(darkTheme: true);
    expect(defaultBackground.toColor().red, equals(0));
    expect(defaultBackground.toColor().green, equals(0));
    expect(defaultBackground.toColor().blue, equals(0));
    expect(defaultBackground.toColor().alpha, equals(255));

    expect(defaultForeground.toColor().red, equals(187));
    expect(defaultForeground.toColor().green, equals(187));
    expect(defaultForeground.toColor().blue, equals(187));
    expect(defaultForeground.toColor().alpha, equals(255));

    expect(customColor.toColor().value, equals(customDark.value));
    expect(customColor.toColor().alpha, equals(customDark.alpha));
    expect(customColor.toColor().red, equals(customDark.red));
    expect(customColor.toColor().green, equals(customDark.green));
    expect(customColor.toColor().blue, equals(customDark.blue));
  });
}
