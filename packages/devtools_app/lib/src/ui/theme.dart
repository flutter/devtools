// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

const contrastForegroundWhite = Color.fromARGB(255, 240, 240, 240);

extension DevToolsColorScheme on ColorScheme {
  bool get isLight => brightness == Brightness.light;
  bool get isDark => brightness == Brightness.dark;

  // Commonly used themed colors.
  Color get defaultBackground => isLight ? Colors.white : Colors.black;

  Color get defaultForeground =>
      isLight ? Colors.black : const Color.fromARGB(255, 187, 187, 187);

  /// Text color [defaultForeground] is too gray, making it hard to read the text
  /// in dark theme. We should use a more white color for dark theme, but not
  /// jarring white #FFFFFF.
  Color get contrastForegroundWhite => const Color.fromARGB(255, 240, 240, 240);

  Color get contrastForeground =>
      isLight ? Colors.black : contrastForegroundWhite;

  Color get grey => isLight
      ? const Color.fromARGB(255, 128, 128, 128)
      : const Color.fromARGB(255, 128, 128, 128);

  /// Background colors for charts.
  Color get chartBackground => isLight ? Colors.white : const Color(0xFF2D2E31);

  Color get defaultButtonIconColor =>
      isLight ? const Color(0xFF24292E) : const Color(0xFF89B5F8);

  Color get defaultPrimaryButtonIconColor => defaultBackground;
}
