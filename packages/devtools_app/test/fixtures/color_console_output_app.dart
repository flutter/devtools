// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:ansicolor/ansicolor.dart';

void main() {
  // Start paused to avoid race conditions getting the initial output from the
  // console.
  developer.debugger();
  print('starting ansi color app');

  // Print out text exercising a wide range of ansi color styles.
  final sb = StringBuffer();
  final pen = AnsiPen();

  // Test the 16 color defaults.
  for (int c = 0; c < 16; c++) {
    pen
      ..reset()
      ..white(bold: true)
      ..xterm(c, bg: true);
    sb.write(pen('$c '));
    pen
      ..reset()
      ..xterm(c);
    sb.write(pen(' $c '));
    if (c == 7 || c == 15) {
      sb.writeln();
    }
  }

  // Test a few custom colors.
  for (int r = 0; r < 6; r += 3) {
    sb.writeln();
    for (int g = 0; g < 6; g += 3) {
      for (int b = 0; b < 6; b += 3) {
        final c = r * 36 + g * 6 + b + 16;
        pen
          ..reset()
          ..rgb(r: r / 5, g: g / 5, b: b / 5, bg: true)
          ..white(bold: true);
        sb.write(pen(' $c '));
        pen
          ..reset()
          ..rgb(r: r / 5, g: g / 5, b: b / 5);
        sb.write(pen(' $c '));
      }
      sb.writeln();
    }
  }

  for (int c = 0; c < 24; c++) {
    if (0 == c % 8) {
      sb.writeln();
    }
    pen
      ..reset()
      ..gray(level: c / 23, bg: true)
      ..white(bold: true);
    sb.write(pen(' ${c + 232} '));
    pen
      ..reset()
      ..gray(level: c / 23);
    sb.write(pen(' ${c + 232} '));
  }
  print(sb.toString());

  // Keep the app running indefinitely printing additional messages.
  int i = 0;
  Timer.periodic(const Duration(milliseconds: 1000), (timer) {
    print('Message ${i++}');
  });
}
