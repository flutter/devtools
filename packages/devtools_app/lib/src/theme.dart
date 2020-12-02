// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'ui/theme.dart';

/// Constructs the light or dark theme for the app taking into account
/// IDE-supplied theming.
ThemeData themeFor({
  @required bool isDarkTheme,
  @required IdeTheme ideTheme,
}) {
  // If the theme specifies a background color, use it to infer a theme.
  if (isValidDarkColor(ideTheme?.backgroundColor)) {
    return _darkTheme(ideTheme);
  } else if (isValidLightColor(ideTheme?.backgroundColor)) {
    return _lightTheme(ideTheme);
  }

  return isDarkTheme ? _darkTheme(ideTheme) : _lightTheme(ideTheme);
}

ThemeData _darkTheme(IdeTheme ideTheme) {
  final theme = ThemeData.dark();
  final background = isValidDarkColor(ideTheme?.backgroundColor)
      ? ideTheme?.backgroundColor
      : theme.canvasColor;

  return theme.copyWith(
    primaryColor: devtoolsGrey[900],
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    indicatorColor: devtoolsBlue[400],
    accentColor: devtoolsBlue[400],
    backgroundColor: devtoolsGrey[600],
    canvasColor: background,
    toggleableActiveColor: devtoolsBlue[400],
    selectedRowColor: devtoolsGrey[600],
    buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth),
    scaffoldBackgroundColor: background,
    colorScheme: theme.colorScheme.copyWith(background: background),
  );
}

ThemeData _lightTheme(IdeTheme ideTheme) {
  final theme = ThemeData.light();
  final background = isValidLightColor(ideTheme?.backgroundColor)
      ? ideTheme?.backgroundColor
      : theme.canvasColor;
  return theme.copyWith(
    primaryColor: devtoolsBlue[600],
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    indicatorColor: Colors.yellowAccent[400],
    accentColor: devtoolsBlue[400],
    backgroundColor: devtoolsGrey[600],
    canvasColor: background,
    toggleableActiveColor: devtoolsBlue[400],
    selectedRowColor: devtoolsBlue[600],
    buttonTheme: theme.buttonTheme.copyWith(minWidth: buttonMinWidth),
    scaffoldBackgroundColor: background,
    colorScheme: theme.colorScheme.copyWith(background: background),
  );
}

/// Threshold used to determine whether a colour is light/dark enough for us to
/// override the default DevTools themes with.
///
/// A value of 0.5 would result in all colours being considered light/dark, and
/// a value of 0.1 allowing around only the 10% darkest/lightest colours by
/// Flutter's luminance calculation.
const _lightDarkLuminanceThreshold = 0.1;

bool isValidDarkColor(Color color) {
  if (color == null) {
    return false;
  }
  return color.computeLuminance() <= _lightDarkLuminanceThreshold;
}

bool isValidLightColor(Color color) {
  if (color == null) {
    return false;
  }
  return color.computeLuminance() >= 1 - _lightDarkLuminanceThreshold;
}

const defaultButtonHeight = 36.0;
const buttonMinWidth = 36.0;

const defaultIconSize = 16.0;
const actionsIconSize = 20.0;
const defaultIconThemeSize = 24.0;

const defaultSpacing = 16.0;
const denseSpacing = 8.0;
const denseRowSpacing = 6.0;

const borderPadding = 2.0;
const densePadding = 4.0;

const smallProgressSize = 12.0;

const defaultListItemHeight = 28.0;

const defaultChartHeight = 150.0;

const defaultTabBarViewPhysics = NeverScrollableScrollPhysics();

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

extension DevToolsColorScheme on ColorScheme {
  Color get devtoolsLink =>
      isLight ? const Color(0xFF1976D2) : Colors.lightBlueAccent;
  // TODO(jacobr): replace this with Theme.of(context).scaffoldBackgroundColor, but we use
  // this in places where we do not have access to the context.
  Color get defaultBackgroundColor =>
      isLight ? Colors.grey[50] : Colors.grey[850];
  Color get chartAccentColor =>
      isLight ? const Color(0xFFCCCCCC) : const Color(0xFF585858);
  Color get chartTextColor => isLight ? Colors.black : Colors.white;
  Color get chartSubtleColor =>
      isLight ? const Color(0xFF999999) : const Color(0xFF8A8A8A);
  Color get toggleButtonBackgroundColor =>
      isLight ? const Color(0xFFE0EEFA) : const Color(0xFF2E3C48);
  // [toggleButtonForegroundColor] is the same for light and dark theme.
  Color get toggleButtonForegroundColor => const Color(0xFF2196F3);
}

TextStyle linkTextStyle(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.devtoolsLink,
      decoration: TextDecoration.underline,
    );

const wideSearchTextWidth = 400.0;
const defaultSearchTextWidth = 200.0;
const defaultTextFieldHeight = 36.0;

/// A short duration to use for animations.
///
/// Use this when you want less emphasis on the animation and more on the
/// animation result, or when you have multiple animations running in sequence
/// For example, in the timeline we use this when we are zooming the flame chart
/// and scrolling to an offset immediately after.
const shortDuration = Duration(milliseconds: 50);

/// A longer duration than [shortDuration] but quicker than [defaultDuration].
///
/// Use this for thinks that would show a bit of animation, but that we want to
/// effectively seem immediate to users.
const rapidDuration = Duration(milliseconds: 100);

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
///
/// Inspector animations benefit from a symmetric animation curve which makes
/// it easier to reverse animations.
const defaultCurve = Curves.easeInOutCubic;

/// Builds a [CurvedAnimation] with [defaultCurve].
///
/// This is the standard curve for animations in DevTools.
CurvedAnimation defaultCurvedAnimation(AnimationController parent) =>
    CurvedAnimation(curve: defaultCurve, parent: parent);

Color titleSolidBackgroundColor(ThemeData theme) {
  return theme.canvasColor.darken(0.2);
}

const chartFontSizeSmall = 12.0;

const lightSelection = Color(0xFFD4D7DA);

/// Return the fixed font style for DevTools.
TextStyle fixedFontStyle(BuildContext context) {
  return Theme.of(context)
      .textTheme
      .bodyText2
      .copyWith(fontFamily: 'RobotoMono', fontSize: 13.0);
}
