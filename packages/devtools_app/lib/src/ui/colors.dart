// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'theme.dart';

/// This file holds color constants that are used throughout DevTools.
// TODO(kenz): move colors from other pages to this file for consistency.

/// Memory heat map blueish color incremental colors from Blue 100 to Blue 900.
Color memoryHeatMapLightColor = const Color(0xFFBBDEFB); // Material BLUE 100
Color memoryHeatMapDarkColor = const Color(0xFF0D47A1); // Material BLUE 900

/// Mark: Timeline / CPU profiler.
///
/// Light mode is Light Blue 50 palette and Dark mode is Blue 50 palette.
/// https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
const mainUiColor = ThemedColor(mainUiColorLight, mainUiColorDark);
const mainRasterColor = ThemedColor(mainRasterColorLight, mainRasterColorDark);
final mainUnknownColor = ThemedColor.fromSingleColor(const Color(0xFFCAB8E9));
final mainAsyncColor = ThemedColor.fromSingleColor(const Color(0xFF80CBC4));

const mainUiColorLight = Color(0xFF81D4FA); // Light Blue 50 - 200
const mainRasterColorLight = Color(0xFF0288D1); // Light Blue 50 - 700

const mainUiColorSelectedLight = Color(0xFFD4D7DA); // Lighter grey.
const mainRasterColorSelectedLight = Color(0xFFB5B5B5); // Darker grey.

const mainUiColorDark = Color(0xFF9EBEF9); // Blue 200 Material Dark
const mainRasterColorDark = Color(0xFF1A73E8); // Blue 600 Material Dark

const mainUiColorSelectedDark = Colors.white;
const mainRasterColorSelectedDark = Color(0xFFC9C9C9); // Grey.

// Light Blue 50: 200-400 (light mode) - see https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
// Blue Material Dark: 200-400 (dark mode) - see https://standards.google/guidelines/google-material/color/dark-theme.html#style.
final uiColorPalette = [
  const ThemedColor(mainUiColorLight, mainUiColorDark),
  const ThemedColor(Color(0xFF4FC3F7), Color(0xFF8AB4F7)),
  const ThemedColor(Color(0xFF29B6F6), Color(0xFF669CF6)),
];

// Light Blue 50: 700-900 (light mode) - see https://material.io/design/color/the-color-system.html#tools-for-picking-colors.
// Blue Material Dark: 500-700 (dark mode) - see https://standards.google/guidelines/google-material/color/dark-theme.html#style.
final rasterColorPalette = [
  const ThemedColor(mainRasterColorLight, mainRasterColorDark),
  const ThemedColor(Color(0xFF0277BD), Color(0xFF1966D2)),
  const ThemedColor(Color(0xFF01579B), Color(0xFF1859BD)),
];

// Teal 200-400 - see https://material.io/design/color/#tools-for-picking-colors.
final asyncColorPalette = [
  mainAsyncColor,
  ThemedColor.fromSingleColor(const Color(0xFF4DB6AC)),
  ThemedColor.fromSingleColor(const Color(0xFF26A69A)),
];

// Slight variation on Deep purple 100-300 - see https://material.io/design/color/#tools-for-picking-colors.
final unknownColorPalette = [
  mainUnknownColor,
  ThemedColor.fromSingleColor(const Color(0xFFB39DDB)),
  ThemedColor.fromSingleColor(const Color(0xFF9D84CA)),
];

final selectedColorPalette = [
  ThemedColor.fromSingleColor(const Color(0xFFBDBDBD)),
  ThemedColor.fromSingleColor(const Color(0xFFADADAD)),
  ThemedColor.fromSingleColor(const Color(0xFF9E9E9E)),
];

const selectedFlameChartItemColor = ThemedColor(
  mainUiColorSelectedLight,
  mainUiColorSelectedLight,
);

final selectedFlutterFrameUiColor = Colors.yellow[500];
final selectedFlutterFrameRasterColor = Colors.yellow[700];

// [mainUiColor] with a red 0.4 opacity overlay.
final uiJankColor = ThemedColor.fromSingleColor(const Color(0xFFCA82A1));
// [mainRasterColor] with a red 0.4 opacity overlay.
final rasterJankColor = ThemedColor.fromSingleColor(const Color(0xFF845697));

// Red 50 - 400 is light at 1/2 opacity, Dark Red 500 Material Dark.
const Color highwater16msColor = mainUiColorSelectedLight;

const Color hoverTextHighContrastColor = Colors.white;

const Color hoverTextColor = Colors.black;

const treeGuidelineColor = ThemedColor(
  Colors.black54,
  Color.fromARGB(255, 200, 200, 200),
);
