// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

bool _isDarkTheme = true;

/// Whether the application is running with a light or dark theme.
///
/// All Dart code that behaves differently depending on whether the current
/// theme is dark or light should use this flag.
///
/// Generally Dart code should use [ThemedColor] everywhere colors are used so
/// that code can be written without directly depending on [isDarkTheme].
///
/// This getter will be deprecated - prefer using the SettingsController class.
@Deprecated('Prefer using the SettingsController')
bool get isDarkTheme => _isDarkTheme;

@Deprecated('Prefer using the SettingsController')
void setTheme({@required bool darkTheme}) {
  _isDarkTheme = darkTheme;
}

// Commonly used themed colors.
const ThemedColor defaultBackground = ThemedColor(Colors.white, Colors.black);
const ThemedColor defaultForeground =
    ThemedColor(Colors.black, Color.fromARGB(255, 187, 187, 187));

// Text color [defaultForeground] is too gray, making it hard to read the text
// in dark theme. We should use a more white color for dark theme, but not
// jarring white #FFFFFF.
const Color contrastForegroundWhite = Color.fromARGB(255, 240, 240, 240);
const ThemedColor contrastForeground =
    ThemedColor(Colors.black, contrastForegroundWhite);

const ThemedColor grey = ThemedColor(
    Color.fromARGB(255, 128, 128, 128), Color.fromARGB(255, 128, 128, 128));

// Background colors for charts.
const ThemedColor chartBackground = ThemedColor(
  Colors.white,
  Color(0xFF2D2E31), // Material Dark Grey 900+2
);

const defaultButtonIconColor = ThemedColor(
  Color(0xFF24292E),
  Color(0xFF89B5F8),
);

const defaultPrimaryButtonIconColor = defaultBackground;

/// Color that behaves differently depending on whether a light or dark theme
/// is used.
///
/// This class is identical in spirit to the JBColor class in IntelliJ to make
/// porting themed colors back and forth between IntelliJ plugin code and
/// devtools code easy.
class ThemedColor {
  const ThemedColor(this._light, this._dark);

  static ThemedColor fromSingleColor(Color color) => ThemedColor(color, color);

  final Color _light;
  final Color _dark;

  // ignore: deprecated_member_use_from_same_package
  Color toColor() => isDarkTheme ? _dark : _light;
}
