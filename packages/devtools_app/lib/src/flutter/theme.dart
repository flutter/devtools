// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Constructs the light or dark theme for the app.
ThemeData themeFor({@required bool isDarkTheme}) {
  final theme = isDarkTheme ? _darkTheme() : _lightTheme();
  return theme;
}

ThemeData _darkTheme() {
  final theme = ThemeData.dark();
  return theme.copyWith(
      primaryColor: devtoolsGrey[900],
      primaryColorDark: devtoolsBlue[700],
      primaryColorLight: devtoolsBlue[400],
      indicatorColor: devtoolsBlue[400],
      accentColor: devtoolsBlue[400],
      backgroundColor: devtoolsGrey[600],
      toggleableActiveColor: devtoolsBlue[400],
      buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth));
}

ThemeData _lightTheme() {
  final theme = ThemeData.light();
  return theme.copyWith(
      primaryColor: devtoolsBlue[600],
      primaryColorDark: devtoolsBlue[700],
      primaryColorLight: devtoolsBlue[400],
      indicatorColor: Colors.yellowAccent[400],
      accentColor: devtoolsBlue[400],
      buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth));
}

const buttonMinWidth = 36.0;

/// Branded grey color.
///
/// Source: https://drive.google.com/open?id=1QBhMJqXyRt-CpRsHR6yw2LAfQtiNat4g
const ColorSwatch<int> devtoolsGrey = ColorSwatch<int>(0xFF202124, {
  900: Color(0xFF202124),
  600: Color(0xFF60646B),
  100: Color(0xFFD5D7Da),
  50: Color(0xFFEAEBEC), // Lerped between grey100 and white
});

/// Branded yellow color.
///
/// Source: https://drive.google.com/open?id=1QBhMJqXyRt-CpRsHR6yw2LAfQtiNat4g
const devtoolsYellow = ColorSwatch<int>(700, {
  700: Color(0xFFFFC108),
});

/// Branded blue color.
///
/// Source: https://drive.google.com/open?id=1QBhMJqXyRt-CpRsHR6yw2LAfQtiNat4g
const devtoolsBlue = ColorSwatch<int>(600, {
  700: Color(0xFF02569B),
  600: Color(0xFF0175C2),
  400: Color(0xFF13B9FD),
});

final chartBackgroundColor = ThemedColor(Colors.grey[50], Colors.grey[850]);
