// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';

import '../ui/theme.dart';

/// Constructs the light or dark theme for the app.
ThemeData themeFor({@required bool isDarkTheme}) {
  return isDarkTheme ? _darkTheme() : _lightTheme();
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
    selectedRowColor: devtoolsGrey[600],
    buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth),
  );
}

ThemeData _lightTheme() {
  final theme = ThemeData.light();
  return theme.copyWith(
    primaryColor: devtoolsBlue[600],
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    indicatorColor: Colors.yellowAccent[400],
    accentColor: devtoolsBlue[400],
    buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth),
  );
}

const buttonMinWidth = 36.0;
const defaultIconSize = 16.0;
const actionsIconSize = 20.0;
const defaultSpacing = 16.0;
const denseSpacing = 8.0;
const denseRowSpacing = 6.0;

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

const devtoolsError = Color(0xFFAF4054);

const devtoolsWarning = Color(0xFFFDFAD5);

const devtoolsLink = ThemedColor(Color(0xFF1976D2), Colors.lightBlueAccent);

/// A short duration to use for animations.
///
/// Use this when you want less emphasis on the animation and more on the
/// animation result, or when you have multiple animations running in sequence
/// For example, in the timeline we use this when we are zooming the flame chart
/// and scrolling to an offset immediately after.
const shortDuration = Duration(milliseconds: 50);

/// The default duration to use for animations.
const defaultDuration = Duration(milliseconds: 200);

/// A long duration to use for animations.
///
/// Use this rarely, only when you want added emphasis to an animation.
const longDuration = Duration(milliseconds: 400);

/// Builds a [defaultDuration] animation controller.
///
/// This is the standard duration to use for animations.
AnimationController defaultAnimationController(
  TickerProvider vsync, {
  double value,
}) {
  return AnimationController(
    duration: defaultDuration,
    vsync: vsync,
    value: value,
  );
}

/// Builds a [longDuration] animation controller.
///
/// This is the standard duration to use for slow animations.
AnimationController longAnimationController(
  TickerProvider vsync, {
  double value,
}) {
  return AnimationController(
    duration: longDuration,
    vsync: vsync,
    value: value,
  );
}

/// The default curve we use for animations.
const defaultCurve = Curves.easeInOutCubic;

/// Builds a [CurvedAnimation] with [defaultCurve].
///
/// This is the standard curve for animations in DevTools.
CurvedAnimation defaultCurvedAnimation(AnimationController parent) =>
    CurvedAnimation(curve: defaultCurve, parent: parent);

final chartBackgroundColor = ThemedColor(Colors.grey[50], Colors.grey[850]);

final chartLightTypeFace = TypeFace(
  fontFamily: 'OpenSans',
  fontWeight: FontWeight.w100,
);

final chartBoldTypeFace = TypeFace(
  fontFamily: 'OpenSans',
  fontWeight: FontWeight.w800,
);

const lightSelection = Color(0xFFD4D7DA);

/// Return the fixed font style for DevTools.
TextStyle fixedFontStyle(BuildContext context) {
  return Theme.of(context)
      .textTheme
      .bodyText2
      .copyWith(fontFamily: 'RobotoMono', fontSize: 13.0);
}
