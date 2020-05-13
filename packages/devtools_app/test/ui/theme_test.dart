// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/ui/flutter_html_shim.dart';
import 'package:devtools_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  const Color customLight = Color.fromARGB(200, 202, 191, 69);
  const Color customDark = Color.fromARGB(100, 99, 101, 103);
  const Color customColor = ThemedColor(customLight, customDark);

  test('light theme', () {
    // ignore: deprecated_member_use_from_same_package
    setTheme(darkTheme: false);
    expect(defaultBackground.red, equals(255));
    expect(defaultBackground.green, equals(255));
    expect(defaultBackground.blue, equals(255));
    expect(defaultBackground.alpha, equals(255));
    expect(colorToCss(defaultBackground), equals('#ffffffff'));

    expect(defaultForeground.red, equals(0));
    expect(defaultForeground.green, equals(0));
    expect(defaultForeground.blue, equals(0));
    expect(defaultForeground.alpha, equals(255));
    expect(colorToCss(defaultForeground), equals('#000000ff'));

    expect(customColor.value, equals(customLight.value));
    expect(customColor.alpha, equals(customLight.alpha));
    expect(customColor.red, equals(customLight.red));
    expect(customColor.green, equals(customLight.green));
    expect(customColor.blue, equals(customLight.blue));
    expect(colorToCss(customColor), colorToCss(customLight));
  });

  test('dark theme', () {
    // ignore: deprecated_member_use_from_same_package
    setTheme(darkTheme: true);
    expect(defaultBackground.red, equals(0));
    expect(defaultBackground.green, equals(0));
    expect(defaultBackground.blue, equals(0));
    expect(defaultBackground.alpha, equals(255));
    expect(colorToCss(defaultBackground), equals('#000000ff'));

    expect(defaultForeground.red, equals(187));
    expect(defaultForeground.green, equals(187));
    expect(defaultForeground.blue, equals(187));
    expect(defaultForeground.alpha, equals(255));
    expect(colorToCss(defaultForeground), equals('#bbbbbbff'));

    expect(customColor.value, equals(customDark.value));
    expect(customColor.alpha, equals(customDark.alpha));
    expect(customColor.red, equals(customDark.red));
    expect(customColor.green, equals(customDark.green));
    expect(customColor.blue, equals(customDark.blue));
    expect(colorToCss(customColor), colorToCss(customDark));
  });
}
