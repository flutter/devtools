// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'flutter_html_shim.dart';

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

  clearColorCache();
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
class ThemedColor implements Color {
  const ThemedColor(this._light, this._dark);

  static ThemedColor fromSingleColor(Color color) => ThemedColor(color, color);

  final Color _light;
  final Color _dark;

  // ignore: deprecated_member_use_from_same_package
  Color get _current => isDarkTheme ? _dark : _light;

  @override
  int get alpha => _current.alpha;

  @override
  int get blue => _current.blue;

  @override
  double computeLuminance() => _current.computeLuminance();

  @override
  int get green => _current.green;

  @override
  double get opacity => _current.opacity;

  @override
  int get red => _current.red;

  @override
  int get value => _current.value;

  @override
  Color withAlpha(int a) => _current.withAlpha(a);

  @override
  Color withBlue(int b) => _current.withBlue(b);

  @override
  Color withGreen(int g) => _current.withGreen(g);

  @override
  Color withOpacity(double opacity) => _current.withOpacity(opacity);

  @override
  Color withRed(int r) => _current.withRed(r);

  // TODO(jacobr): remove these methods when they are removed from flutter_web.
  // @override only on Flutter Web
  String toCssString() => (_current as dynamic).toCssString();

  // TODO(jacobr): remove these methods when they are removed from flutter_web.
  // @override only on Flutter Web
  String toCssStringRgbOnly() => (_current as dynamic).toCssStringRgbOnly();
}
