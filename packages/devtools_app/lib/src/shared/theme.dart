// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'config_specific/ide_theme/ide_theme.dart';
import 'ui/colors.dart';
import 'utils.dart';

// TODO(kenz): try to eliminate as many custom colors as possible, and pull
// colors only from the [lightColorScheme] and the [darkColorScheme].

const _contrastForegroundWhite = Color.fromARGB(255, 240, 240, 240);

const contrastForegroundWhite = _contrastForegroundWhite;

/// Constructs the light or dark theme for the app taking into account
/// IDE-supplied theming.
ThemeData themeFor({
  required bool isDarkTheme,
  required IdeTheme ideTheme,
  required ThemeData theme,
}) {
  final colorTheme = isDarkTheme
      ? _darkTheme(ideTheme: ideTheme, theme: theme)
      : _lightTheme(ideTheme: ideTheme, theme: theme);

  return colorTheme.copyWith(
    primaryTextTheme: theme.primaryTextTheme
        .merge(colorTheme.primaryTextTheme)
        .apply(fontSizeFactor: ideTheme.fontSizeFactor),
    textTheme: theme.textTheme
        .merge(colorTheme.textTheme)
        .apply(fontSizeFactor: ideTheme.fontSizeFactor),
  );
}

ThemeData _darkTheme({
  required IdeTheme ideTheme,
  required ThemeData theme,
}) {
  final background = isValidDarkColor(ideTheme.backgroundColor)
      ? ideTheme.backgroundColor!
      : theme.colorScheme.surface;
  return _baseTheme(
    theme: theme,
    backgroundColor: background,
  );
}

ThemeData _lightTheme({
  required IdeTheme ideTheme,
  required ThemeData theme,
}) {
  final background = isValidLightColor(ideTheme.backgroundColor)
      ? ideTheme.backgroundColor!
      : theme.colorScheme.surface;
  return _baseTheme(
    theme: theme,
    backgroundColor: background,
  );
}

ThemeData _baseTheme({
  required ThemeData theme,
  required Color backgroundColor,
}) {
  // TODO(kenz): do we need to pass in the foreground color from the [IdeTheme]
  // as well as the background color?
  return theme.copyWith(
    tabBarTheme: theme.tabBarTheme.copyWith(
      dividerColor: Colors.transparent,
      labelPadding:
          const EdgeInsets.symmetric(horizontal: defaultTabBarPadding),
    ),
    canvasColor: backgroundColor,
    scaffoldBackgroundColor: backgroundColor,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(densePadding),
        minimumSize: Size(defaultButtonHeight, defaultButtonHeight),
        fixedSize: Size(defaultButtonHeight, defaultButtonHeight),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: Size.fromHeight(defaultButtonHeight),
        foregroundColor: theme.colorScheme.onSurface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(densePadding),
        minimumSize: Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: Size.fromHeight(defaultButtonHeight),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(buttonMinWidth, defaultButtonHeight),
        fixedSize: Size.fromHeight(defaultButtonHeight),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearMinHeight: defaultLinearProgressIndicatorHeight,
    ),
  );
}

/// Light theme color scheme generated from DevTools Figma file.
///
/// Do not manually change these values.
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF195BB9),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD8E2FF),
  onPrimaryContainer: Color(0xFF001A41),
  secondary: Color(0xFF575E71),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDBE2F9),
  onSecondaryContainer: Color(0xFF141B2C),
  tertiary: Color(0xFF815600),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFFDDB1),
  onTertiaryContainer: Color(0xFF291800),
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD5),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFFFFFFF),
  onBackground: Color(0xFF1B1B1F),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B1B1F),
  surfaceVariant: Color(0xFFE1E2EC),
  onSurfaceVariant: Color(0xFF44474F),
  outline: Color(0xFF75777F),
  onInverseSurface: Color(0xFFF2F0F4),
  inverseSurface: Color(0xFF303033),
  inversePrimary: Color(0xFFADC6FF),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF195BB9),
  outlineVariant: Color(0xFFC4C6D0),
  scrim: Color(0xFF000000),
);

/// Dark theme color scheme generated from DevTools Figma file.
///
/// Do not manually change these values.
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFADC6FF),
  onPrimary: Color(0xFF002E69),
  primaryContainer: Color(0xFF004494),
  onPrimaryContainer: Color(0xFFD8E2FF),
  secondary: Color(0xFFBFC6DC),
  onSecondary: Color(0xFF293041),
  secondaryContainer: Color(0xFF3F4759),
  onSecondaryContainer: Color(0xFFDBE2F9),
  tertiary: Color(0xFFFEBA4B),
  onTertiary: Color(0xFF442B00),
  tertiaryContainer: Color(0xFF624000),
  onTertiaryContainer: Color(0xFFFFDDB1),
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF930009),
  onError: Color(0xFF690004),
  onErrorContainer: Color(0xFFFFDAD5),
  background: Color(0xFF1B1B1F),
  onBackground: Color(0xFFE3E2E6),
  surface: Color(0xFF1B1B1F),
  onSurface: Color(0xFFC7C6CA),
  surfaceVariant: Color(0xFF44474F),
  onSurfaceVariant: Color(0xFFC4C6D0),
  outline: Color(0xFF8E9099),
  onInverseSurface: Color(0xFF1B1B1F),
  inverseSurface: Color(0xFFE3E2E6),
  inversePrimary: Color(0xFF195BB9),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFFADC6FF),
  outlineVariant: Color(0xFF44474F),
  scrim: Color(0xFF000000),
);

/// Threshold used to determine whether a colour is light/dark enough for us to
/// override the default DevTools themes with.
///
/// A value of 0.5 would result in all colours being considered light/dark, and
/// a value of 0.1 allowing around only the 10% darkest/lightest colours by
/// Flutter's luminance calculation.
const _lightDarkLuminanceThreshold = 0.1;

bool isValidDarkColor(Color? color) {
  if (color == null) {
    return false;
  }
  return color.computeLuminance() <= _lightDarkLuminanceThreshold;
}

bool isValidLightColor(Color? color) {
  if (color == null) {
    return false;
  }
  return color.computeLuminance() >= 1 - _lightDarkLuminanceThreshold;
}

double get defaultToolbarHeight => scaleByFontFactor(32.0);
double get defaultHeaderHeight =>
    isDense() ? scaleByFontFactor(34.0) : scaleByFontFactor(38.0);
const defaultTabBarPadding = 14.0;

double get defaultButtonHeight => scaleByFontFactor(32.0);
double get smallButtonHeight => scaleByFontFactor(20.0);
double get defaultSwitchHeight => scaleByFontFactor(26.0);
double get defaultLinearProgressIndicatorHeight => scaleByFontFactor(4.0);

double get buttonMinWidth => scaleByFontFactor(36.0);

double get defaultIconSize => scaleByFontFactor(defaultIconSizeBeforeScaling);
double get actionsIconSize =>
    scaleByFontFactor(defaultActionsIconSizeBeforeScaling);
double get tooltipIconSize => scaleByFontFactor(12.0);
double get tableIconSize => scaleByFontFactor(12.0);

const defaultIconSizeBeforeScaling = 16.0;
const defaultActionsIconSizeBeforeScaling = 20.0;

const largeSpacing = 32.0;
const defaultSpacing = 16.0;
const tabBarSpacing = 14.0;
const intermediateSpacing = 12.0;
const denseSpacing = 8.0;
const denseModeDenseSpacing = 2.0;
const denseRowSpacing = 6.0;

const defaultBorderRadius = 16.0;
const defaultElevation = 4.0;

const borderPadding = 2.0;
const densePadding = 4.0;
const noPadding = 0.0;

double get smallProgressSize => scaleByFontFactor(12.0);
double get mediumProgressSize => scaleByFontFactor(24.0);

double get defaultListItemHeight => scaleByFontFactor(28.0);

// TODO(jacobr) define a more sophisticated formula for chart height.
// The chart height does need to increase somewhat to leave room for the legend
// and tick marks but does not need to scale linearly with the font factor.
double get defaultChartHeight => scaleByFontFactor(120.0);

/// Width of all settings dialogs.
double get dialogSettingsWidth => scaleByFontFactor(700.0);

const defaultScrollBarOffset = 10.0;

const defaultTabBarViewPhysics = NeverScrollableScrollPhysics();

double get defaultDialogWidth => scaleByFontFactor(700.0);

const unscaledDefaultFontSize = 14.0;
double get defaultFontSize => scaleByFontFactor(unscaledDefaultFontSize);

double get consoleLineHeight => scaleByFontFactor(18.0);

double get actionWidgetSize => scaleByFontFactor(48.0);

double get statusLineHeight => scaleByFontFactor(24.0);

double get inputDecorationElementHeight => scaleByFontFactor(20.0);

const chartTextFontSize = 10.0;

const devtoolsGreen = Color(0xFF5BC43B);

extension DevToolsColorScheme on ColorScheme {
  bool get isLight => brightness == Brightness.light;

  bool get isDark => brightness == Brightness.dark;

  Color get warningContainer => tertiaryContainer;

  Color get onWarningContainer => onTertiaryContainer;

  Color get onWarningContainerLink =>
      isLight ? tertiary : const Color(0xFFDF9F32);

  Color get onErrorContainerLink => isLight ? error : const Color(0xFFFF897D);

  Color get subtleTextColor => const Color(0xFF919094);

  Color get overlayShadowColor => const Color.fromRGBO(0, 0, 0, 0.5);

  Color get overlayBackgroundColor =>
      isLight ? Colors.white : const Color(0xFF424242);

  Color get grey => const Color.fromARGB(255, 128, 128, 128);

  Color get breakpointColor => primary;

  /// Background colors for charts.
  Color get chartBackground => isLight ? Colors.white : const Color(0xFF2D2E31);

  Color get devtoolsLink =>
      isLight ? const Color(0xFF1976D2) : Colors.lightBlueAccent;

  Color get devtoolsSelectedLink =>
      isLight ? Colors.white : Colors.lightBlueAccent;

  // TODO(jacobr): replace this with Theme.of(context).scaffoldBackgroundColor, but we use
  // this in places where we do not have access to the context.
  // remove.
  // TODO(kenz): get rid of this.
  Color get defaultBackgroundColor =>
      isLight ? Colors.grey[50]! : const Color(0xFF1B1B1F);

  Color get alternatingBackgroundColor1 =>
      isLight ? Colors.white : const Color(0xFF1B1B1F);

  Color get alternatingBackgroundColor2 =>
      isLight ? const Color(0xFFF2F0F4) : const Color(0xFF303033);

  Color get selectedRowBackgroundColor =>
      isLight ? const Color(0xFFC7C6CA) : const Color(0xFF5E5E62);

  Color get chartAccentColor =>
      isLight ? const Color(0xFFCCCCCC) : const Color(0xFF585858);

  Color get chartTextColor => isLight ? Colors.black : Colors.white;

  Color get chartSubtleColor =>
      isLight ? const Color(0xFF999999) : const Color(0xFF8A8A8A);

  Color get tooltipTextColor => isLight ? Colors.white : Colors.black;

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
      isLight ? Colors.lime[600]! : Colors.yellowAccent;

  // Highlight color for an selected item in the autocomplete dropdown list.
  Color get autoCompleteHighlightColor =>
      isLight ? Colors.grey[300]! : Colors.grey[700]!;

  Color get autoCompleteTextColor => isLight ? Colors.black : Colors.white;

  Color get expandedColor => isLight ? Colors.grey[200]! : Colors.grey[800]!;

  Color get expandedTopContentColor =>
      isLight ? Colors.grey[50]! : Colors.grey[850]!;

  Color get expandedBottomContentColor =>
      isLight ? Colors.grey[200]! : Colors.grey[800]!;

  Gradient get verticalGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [expandedTopContentColor, expandedBottomContentColor],
        tileMode: TileMode.repeated,
      );

  Color get performanceLowImpactColor => const Color(0xFF5CB246);
  Color get performanceMediumImpactColor => const Color(0xFFF7AC2A);
  Color get performanceHighImpactColor => const Color(0xFFC94040);

  Color get coverageHitColor => performanceLowImpactColor;
  Color get coverageMissColor => performanceHighImpactColor;

  List<Color> get treeGuidelineColors => [
        const Color(0xFF13B9FD),
        devtoolsGreen,
      ];
}

/// Utility extension methods to the [ThemeData] class.
extension ThemeDataExtension on ThemeData {
  /// Returns whether we are currently using a dark theme.
  bool get isDarkTheme => brightness == Brightness.dark;

  TextStyle get regularTextStyle => _fixBlurryText(
        TextStyle(
          color: colorScheme.onSurface,
          fontSize: defaultFontSize,
        ),
      );

  TextStyle get subtleTextStyle => _fixBlurryText(
        TextStyle(
          color: colorScheme.subtleTextColor,
        ),
      );

  TextStyle get fixedFontStyle => _fixBlurryText(
        textTheme.bodyMedium!.copyWith(
          fontFamily: 'RobotoMono',
          color: colorScheme.onSurface,
          // Slightly smaller for fixes font text since it will appear larger
          // to begin with.
          fontSize: defaultFontSize - 1,
        ),
      );

  TextStyle get subtleFixedFontStyle => fixedFontStyle.copyWith(
        color: colorScheme.subtleTextColor,
      );

  TextStyle get selectedSubtleTextStyle =>
      subtleTextStyle.copyWith(color: colorScheme.onSurface);

  TextStyle get tooltipFixedFontStyle => fixedFontStyle.copyWith(
        color: colorScheme.tooltipTextColor,
      );

  TextStyle get fixedFontLinkStyle => fixedFontStyle.copyWith(
        color: colorScheme.devtoolsLink,
        decoration: TextDecoration.underline,
      );

  TextStyle get devToolsTitleStyle => _fixBlurryText(textTheme.titleMedium!);

  TextStyle get linkTextStyle => _fixBlurryText(
        TextStyle(
          color: colorScheme.devtoolsLink,
          decoration: TextDecoration.underline,
          fontSize: defaultFontSize,
        ),
      );

  TextStyle get selectedLinkTextStyle => _fixBlurryText(
        linkTextStyle.copyWith(color: colorScheme.devtoolsSelectedLink),
      );

  TextStyle get subtleChartTextStyle => _fixBlurryText(
        TextStyle(
          color: colorScheme.chartSubtleColor,
          fontSize: chartFontSizeSmall,
        ),
      );

  TextStyle get searchMatchHighlightStyle => _fixBlurryText(
        const TextStyle(
          color: Colors.black,
          backgroundColor: activeSearchMatchColor,
        ),
      );

  TextStyle get searchMatchHighlightStyleFocused => _fixBlurryText(
        const TextStyle(
          color: Colors.black,
          backgroundColor: searchMatchColor,
        ),
      );

  // Title of the hover card.
  TextStyle get hoverTitleTextStyle => _fixBlurryText(
        TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: scaleByFontFactor(15.0),
          decoration: TextDecoration.none,
        ),
      );

  // Last allocation timestamp displayed.
  TextStyle get italicTextStyle => _fixBlurryText(
        TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: scaleByFontFactor(14.0),
          fontStyle: FontStyle.italic,
          decoration: TextDecoration.none,
        ),
      );

  // Items in a chart's legend.
  TextStyle get legendTextStyle => _fixBlurryText(
        TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: chartFontSizeSmall,
          decoration: TextDecoration.none,
        ),
      );

  /// TextStyle for callstack.
  TextStyle get stackTraceCall => _fixBlurryText(
        TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: scaleByFontFactor(12.0),
        ),
      );

  /// TextStyle for source file displayed in callstack.
  TextStyle get stackTraceSource => _fixBlurryText(
        TextStyle(
          fontWeight: FontWeight.w100,
          fontSize: scaleByFontFactor(12.0),
        ),
      );

  TextStyle _fixBlurryText(TextStyle style) {
    return style.copyWith(
      fontFeatures: [const FontFeature.proportionalFigures()],
    );
  }
}

const extraWideSearchFieldWidth = 600.0;
const wideSearchFieldWidth = 400.0;
const defaultSearchFieldWidth = 200.0;
double get defaultTextFieldHeight => scaleByFontFactor(32.0);
double get defaultTextFieldNumberWidth => scaleByFontFactor(100.0);

double get maxHoverCardHeight => scaleByFontFactor(250.0);
const hoverCardBorderWidth = 2.0;

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
  double? value,
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
  double? value,
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

double get chartFontSizeSmall => scaleByFontFactor(10.0);

const lightSelection = Color(0xFFD4D7DA);

bool includeText(
  BuildContext context,
  double? minScreenWidthForTextBeforeScaling,
) {
  return minScreenWidthForTextBeforeScaling == null ||
      MediaQuery.of(context).size.width >
          scaleByFontFactor(minScreenWidthForTextBeforeScaling);
}

ButtonStyle denseAwareOutlinedButtonStyle(
  BuildContext context,
  double? minScreenWidthForTextBeforeScaling,
) {
  final buttonStyle =
      Theme.of(context).outlinedButtonTheme.style ?? const ButtonStyle();
  return _generateButtonStyle(
    context: context,
    buttonStyle: buttonStyle,
    minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
  );
}

ButtonStyle denseAwareTextButtonStyle(
  BuildContext context, {
  double? minScreenWidthForTextBeforeScaling,
}) {
  final buttonStyle =
      Theme.of(context).textButtonTheme.style ?? const ButtonStyle();
  return _generateButtonStyle(
    context: context,
    buttonStyle: buttonStyle,
    minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
  );
}

ButtonStyle _generateButtonStyle({
  required BuildContext context,
  required ButtonStyle buttonStyle,
  double? minScreenWidthForTextBeforeScaling,
}) {
  if (!includeText(context, minScreenWidthForTextBeforeScaling)) {
    buttonStyle = buttonStyle.copyWith(
      padding: MaterialStateProperty.resolveWith<EdgeInsets>((_) {
        return EdgeInsets.zero;
      }),
    );
  }
  return buttonStyle;
}
