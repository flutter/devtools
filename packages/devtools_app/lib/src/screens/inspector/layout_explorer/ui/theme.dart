// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

const margin = 8.0;

double get arrowHeadSize => scaleByFontFactor(8.0);
double get arrowMargin => scaleByFontFactor(4.0);
const arrowStrokeWidth = 1.5;

/// Hardcoded sizes for scaling the flex children widget properly.
double get minRenderWidth => scaleByFontFactor(250.0);
double get minRenderHeight => scaleByFontFactor(250.0);

const minPadding = 2.0;
const overflowTextHorizontalPadding = 8.0;

/// The size to shrink a widget by when animating it in.
const entranceMargin = 50.0;

double get defaultMaxRenderWidth => scaleByFontFactor(400.0);
double get defaultMaxRenderHeight => scaleByFontFactor(400.0);

const widgetTitleMaxWidthPercentage = 0.75;

/// Hardcoded arrow size respective to its cross axis (because it's unconstrained).
double get heightAndConstraintIndicatorSize => scaleByFontFactor(48.0);
double get widthAndConstraintIndicatorSize => scaleByFontFactor(56.0);
double get mainAxisArrowIndicatorSize => scaleByFontFactor(48.0);
double get crossAxisArrowIndicatorSize => scaleByFontFactor(48.0);

double get heightOnlyIndicatorSize => scaleByFontFactor(72.0);

/// Minimum size to display width/height inside the arrow
double get minWidthToDisplayWidthInsideArrow => scaleByFontFactor(200.0);
double get minHeightToDisplayHeightInsideArrow => scaleByFontFactor(200.0);

const largeTextScaleFactor = 1.2;
const smallTextScaleFactor = 0.8;

/// Height for limiting asset image (selected one in the drop down).
double get axisAlignmentAssetImageHeight => scaleByFontFactor(24.0);

double get dropdownMaxSize => scaleByFontFactor(220.0);

double get minHeightToAllowTruncating => scaleByFontFactor(375.0);
double get minWidthToAllowTruncating => scaleByFontFactor(375.0);

// Story of Layout colors
const mainAxisLightColor = Color(0xff2c5daa);
const mainAxisDarkColor = Color(0xff2c5daa);

const textColor = Color(0xff55767f);
const emphasizedTextColor = Color(0xff009aca);

const crossAxisLightColor = Color(0xff8ac652);
const crossAxisDarkColor = Color(0xff8ac652);

const mainAxisTextColorLight = Color(0xFF1375bc);
const mainAxisTextColorDark = Color(0xFF1375bc);

const crossAxisTextColorLight = Color(0xFF66672C);
const crossAxisTextColorsDark = Color(0xFFB3D25A);

const overflowBackgroundColorDark = Color(0xFFB00020);
const overflowBackgroundColorLight = Color(0xFFB00020);

const overflowTextColorDark = Color(0xfff5846b);
const overflowTextColorLight = Color(0xffdea089);

const backgroundColorSelectedDark = Color(
  0x4d474747,
); // TODO(jacobr): we would like Color(0x4dedeeef) but that makes the background show through.
const backgroundColorSelectedLight = Color(0x4dedeeef);

extension LayoutExplorerColorScheme on ColorScheme {
  Color get mainAxisColor => isLight ? mainAxisLightColor : mainAxisDarkColor;

  Color get widgetNameColor => isLight ? Colors.white : Colors.black;

  Color get crossAxisColor =>
      isLight ? crossAxisLightColor : crossAxisDarkColor;

  Color get mainAxisTextColor =>
      isLight ? mainAxisTextColorLight : mainAxisTextColorDark;

  Color get crossAxisTextColor =>
      isLight ? crossAxisTextColorLight : crossAxisTextColorsDark;

  Color get overflowBackgroundColor =>
      isLight ? overflowBackgroundColorLight : overflowBackgroundColorDark;

  Color get overflowTextColor =>
      isLight ? overflowTextColorLight : overflowTextColorDark;

  Color get backgroundColorSelected =>
      isLight ? backgroundColorSelectedLight : backgroundColorSelectedDark;

  Color get unconstrainedColor =>
      isLight ? unconstrainedLightColor : unconstrainedDarkColor;
}

const backgroundColorDark = Color(0xff30302f);
const backgroundColorLight = Color(0xffffffff);

const unconstrainedDarkColor = Color(0xffdea089);
const unconstrainedLightColor = Color(0xfff5846b);

const widthIndicatorColor = textColor;
const heightIndicatorColor = textColor;

const negativeSpaceDarkAssetName =
    'assets/img/layout_explorer/negative_space_dark.png';
const negativeSpaceLightAssetName =
    'assets/img/layout_explorer/negative_space_light.png';

const dimensionIndicatorTextStyle = TextStyle(
  height: 1.0,
  letterSpacing: 1.1,
  color: emphasizedTextColor,
);

TextStyle overflowingDimensionIndicatorTextStyle(ColorScheme colorScheme) =>
    dimensionIndicatorTextStyle.merge(
      TextStyle(
        fontWeight: FontWeight.bold,
        color: colorScheme.overflowTextColor,
      ),
    );

Widget buildUnderline() {
  return Container(
    height: 1.0,
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: textColor,
          width: 0.0,
        ),
      ),
    ),
  );
}
