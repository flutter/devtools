// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'config_specific/ide_theme/ide_theme.dart';

const _contrastForegroundWhite = Color.fromARGB(255, 240, 240, 240);

const contrastForegroundWhite = _contrastForegroundWhite;

/// Constructs the light or dark theme for the app taking into account
/// IDE-supplied theming.
ThemeData themeFor({
  @required bool isDarkTheme,
  @required IdeTheme ideTheme,
  ThemeData theme,
}) {
  ThemeData colorTheme;
  // If the theme specifies a background color, use it to infer a theme.
  if (isValidDarkColor(ideTheme?.backgroundColor)) {
    colorTheme = _darkTheme(ideTheme);
  } else if (isValidLightColor(ideTheme?.backgroundColor)) {
    colorTheme = _lightTheme(ideTheme);
  } else {
    colorTheme = isDarkTheme ? _darkTheme(ideTheme) : _lightTheme(ideTheme);
  }

  return colorTheme.copyWith(
    primaryTextTheme: (theme != null
            ? theme.primaryTextTheme.merge(colorTheme.primaryTextTheme)
            : colorTheme.primaryTextTheme)
        .apply(fontSizeFactor: ideTheme?.fontSizeFactor ?? 1.0),
    textTheme: (theme != null
            ? theme.textTheme.merge(colorTheme.textTheme)
            : colorTheme.textTheme)
        .apply(fontSizeFactor: ideTheme?.fontSizeFactor ?? 1.0),
  );
}

ThemeData _darkTheme(IdeTheme ideTheme) {
  final theme = ThemeData.dark();
  final background = isValidDarkColor(ideTheme?.backgroundColor)
      ? ideTheme?.backgroundColor
      : theme.canvasColor;
  return _baseTheme(
    theme: theme,
    ideTheme: ideTheme,
    primaryColor: devtoolsGrey[900],
    backgroundColor: background,
    indicatorColor: devtoolsBlue[400],
    selectedRowColor: devtoolsGrey[600],
  );
}

ThemeData _lightTheme(IdeTheme ideTheme) {
  final theme = ThemeData.light();
  final background = isValidLightColor(ideTheme?.backgroundColor)
      ? ideTheme?.backgroundColor
      : theme.canvasColor;
  return _baseTheme(
    theme: theme,
    ideTheme: ideTheme,
    primaryColor: devtoolsBlue[600],
    backgroundColor: background,
    indicatorColor: Colors.yellowAccent[400],
    selectedRowColor: devtoolsBlue[600],
  );
}

ThemeData _baseTheme({
  @required ThemeData theme,
  @required IdeTheme ideTheme,
  @required Color primaryColor,
  @required Color backgroundColor,
  @required Color indicatorColor,
  @required Color selectedRowColor,
}) {
  return theme.copyWith(
    primaryColor: primaryColor,
    indicatorColor: indicatorColor,
    selectedRowColor: selectedRowColor,
    // Same values for both light and dark themes.
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    // ignore: deprecated_member_use
    accentColor: devtoolsBlue[400],
    backgroundColor: devtoolsGrey[600],
    toggleableActiveColor: devtoolsBlue[400],
    canvasColor: backgroundColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: theme.colorScheme.copyWith(background: backgroundColor),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        primary: theme.colorScheme.contrastForeground,
        minimumSize: const Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: const Size.fromHeight(defaultButtonHeight),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        primary: theme.colorScheme.contrastForeground,
        minimumSize: const Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: const Size.fromHeight(defaultButtonHeight),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: const Size.fromHeight(defaultButtonHeight),
      ),
    ),
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

const defaultToolbarHeight = 32.0;

const defaultButtonHeight = 32.0;
const smallButtonHeight = 20.0;

const buttonMinWidth = 36.0;

const defaultIconSize = 16.0;
const actionsIconSize = 20.0;

const defaultSpacing = 16.0;
const denseSpacing = 8.0;
const denseModeDenseSpacing = 2.0;
const denseRowSpacing = 6.0;

const defaultBorderRadius = 4.0;
const defaultElevation = 4.0;

const borderPadding = 2.0;
const densePadding = 4.0;

const smallProgressSize = 12.0;

const defaultListItemHeight = 28.0;

const defaultChartHeight = 150.0;

/// Width of all settings dialogs.
const dialogSettingsWidth = 700.0;

const defaultScrollBarOffset = 10.0;

const defaultTabBarViewPhysics = NeverScrollableScrollPhysics();

const defaultDialogWidth = 700.0;

const defaultFontSize = 14.0;

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
  bool get isLight => brightness == Brightness.light;

  bool get isDark => brightness == Brightness.dark;

  // Commonly used themed colors.
  Color get defaultBackground => isLight ? Colors.white : Colors.black;

  Color get defaultForeground =>
      isLight ? Colors.black : const Color.fromARGB(255, 187, 187, 187);

  /// Text color [defaultForeground] is too gray, making it hard to read the text
  /// in dark theme. We should use a more white color for dark theme, but not
  /// jarring white #FFFFFF.
  Color get contrastForegroundWhite => _contrastForegroundWhite;

  Color get contrastForeground =>
      isLight ? Colors.black : _contrastForegroundWhite;

  Color get serviceExtensionButtonsTitle =>
      isLight ? const Color(0xFF464646) : const Color(0xFFAEAEB1);

  Color get serviceExtensionButtonsTitleSelected =>
      isLight ? Colors.white : const Color(0xFF464646);

  Color get serviceExtensionButtonsFillSelected => devtoolsBlue[400];

  Color get grey => isLight
      ? const Color.fromARGB(255, 128, 128, 128)
      : const Color.fromARGB(255, 128, 128, 128);

  /// Background colors for charts.
  Color get chartBackground => isLight ? Colors.white : const Color(0xFF2D2E31);

  Color get defaultButtonIconColor =>
      isLight ? const Color(0xFF24292E) : const Color(0xFF89B5F8);

  Color get defaultPrimaryButtonIconColor => defaultBackground;

  Color get devtoolsLink =>
      isLight ? const Color(0xFF1976D2) : Colors.lightBlueAccent;

  // TODO(jacobr): replace this with Theme.of(context).scaffoldBackgroundColor, but we use
  // this in places where we do not have access to the context.
  Color get defaultBackgroundColor =>
      isLight ? Colors.grey[50] : Colors.grey[850];

  Color get alternatingBackgroundColor => isLight
      ? defaultBackgroundColor.darken()
      : defaultBackgroundColor.brighten();

  Color get chartAccentColor =>
      isLight ? const Color(0xFFCCCCCC) : const Color(0xFF585858);

  Color get chartTextColor => isLight ? Colors.black : Colors.white;

  Color get chartSubtleColor =>
      isLight ? const Color(0xFF999999) : const Color(0xFF8A8A8A);

  Color get toggleButtonBackgroundColor =>
      isLight ? const Color(0xFFE0EEFA) : const Color(0xFF2E3C48);

  // [toggleButtonForegroundColor] is the same for light and dark theme.
  Color get toggleButtonForegroundColor => const Color(0xFF2196F3);

  Color get functionSyntaxColor =>
      isLight ? const Color(0xFF795E26) : const Color(0xFFDCDCAA);

  Color get declarationsSyntaxColor =>
      isLight ? const Color(0xFF267f99) : const Color(0xFF4EC9B0);

  Color get modifierSyntaxColor =>
      isLight ? const Color(0xFF0000FF) : const Color(0xFF569CD6);

  Color get controlFlowSyntaxColor =>
      isLight ? const Color(0xFFAF00DB) : const Color(0xFFC586C0);

  Color get variableSyntaxColor =>
      isLight ? const Color(0xFF001080) : const Color(0xFF9CDCFE);

  Color get commentSyntaxColor =>
      isLight ? const Color(0xFF008000) : const Color(0xFF6A9955);

  Color get stringSyntaxColor =>
      isLight ? const Color(0xFFB20001) : const Color(0xFFD88E73);

  Color get numericConstantSyntaxColor =>
      isLight ? const Color(0xFF098658) : const Color(0xFFB5CEA8);

  // Bar color for current selection (hover).
  Color get hoverSelectionBarColor =>
      isLight ? Colors.lime[600] : Colors.yellowAccent;

  // Highlight color for an selected item in the autocomplete dropdown list.
  Color get autoCompleteHighlightColor =>
      isLight ? Colors.grey[300] : Colors.grey[700];

  // Title of the hover card.
  TextStyle get hoverTitleTextStyle => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 15,
        decoration: TextDecoration.none,
      );

  // Items in the hover card.
  TextStyle get hoverTextStyle => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 11.5,
        decoration: TextDecoration.none,
      );

  // Value of items in hover e.g., capacity, etc.
  TextStyle get hoverValueTextStyle => TextStyle(
        color: contrastForeground,
        fontWeight: FontWeight.normal,
        fontSize: 11.5,
        decoration: TextDecoration.none,
      );

  // Used for custom extension event values.
  TextStyle get hoverSmallValueTextStyle => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 10,
        decoration: TextDecoration.none,
      );

  // Last allocation timestamp displayed.
  TextStyle get italicTextStyle => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 14,
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.none,
      );

  // Items in a chart's legend.
  TextStyle get legendTextStyle => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 10,
        decoration: TextDecoration.none,
      );

  Color get expandedColor => isLight ? Colors.grey[200] : Colors.grey[800];

  Color get expandedTopContentColor =>
      isLight ? Colors.grey[50] : Colors.grey[850];

  Color get expandedBottomContentColor =>
      isLight ? Colors.grey[200] : Colors.grey[800];

  Gradient get verticalGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [expandedTopContentColor, expandedBottomContentColor],
        tileMode: TileMode.repeated,
      );

  /// TextStyle for callstack.
  TextStyle get stackTraceCall => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      );

  /// TextStyle for source file displayed in callstack.
  TextStyle get stackTraceSource => TextStyle(
        color: defaultForeground,
        fontWeight: FontWeight.w100,
        fontSize: 12,
      );
}

/// Utility extension methods to the [ThemeData] class.
extension ThemeDataExtension on ThemeData {
  /// Returns whether we are currently using a dark theme.
  bool get isDarkTheme => brightness == Brightness.dark;

  TextStyle get regularTextStyle => TextStyle(color: textTheme.bodyText2.color);

  TextStyle get subtleTextStyle => TextStyle(color: unselectedWidgetColor);

  TextStyle get selectedTextStyle =>
      TextStyle(color: textSelectionTheme.selectionColor);

  TextStyle get fixedFontStyle =>
      textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono');

  TextStyle get subtleFixedFontStyle =>
      fixedFontStyle.copyWith(color: unselectedWidgetColor);

  TextStyle get devToolsTitleStyle =>
      textTheme.headline6.copyWith(color: Colors.white);

  Color get titleSolidBackgroundColor => colorScheme.isLight
      ? colorScheme.alternatingBackgroundColor
      : canvasColor.darken(0.2);
}

TextStyle linkTextStyle(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.devtoolsLink,
      decoration: TextDecoration.underline,
    );

const wideSearchTextWidth = 400.0;
const defaultSearchTextWidth = 200.0;
const defaultTextFieldHeight = 32.0;

const maxHoverCardHeight = 250.0;

/// Default color of cursor and color used by search's TextField.
/// Guarantee that the Search TextField on all platforms renders in the same
/// color for border, label text, and cursor. Primarly, so golden screen
/// snapshots will compare successfully using the exact color.
Color searchColor = Colors.blue;

/// Default Border of search's TextField.
BorderSide searchFocusBorderColor = BorderSide(color: searchColor, width: 2);

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

const chartFontSizeSmall = 12.0;

const lightSelection = Color(0xFFD4D7DA);

bool includeText(BuildContext context, double includeTextWidth) {
  return includeTextWidth == null ||
      MediaQuery.of(context).size.width > includeTextWidth;
}

ButtonStyle denseAwareOutlinedButtonStyle(
  BuildContext context,
  double includeTextWidth,
) {
  var buttonStyle = Theme.of(context).outlinedButtonTheme.style;
  if (!includeText(context, includeTextWidth)) {
    buttonStyle = buttonStyle.copyWith(
      padding: MaterialStateProperty.resolveWith<EdgeInsets>((_) {
        return EdgeInsets.zero;
      }),
    );
  }
  return buttonStyle;
}
