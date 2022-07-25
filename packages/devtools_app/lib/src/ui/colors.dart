// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../shared/theme.dart';
import 'utils.dart';

/// This file holds color constants that are used throughout DevTools.
// TODO(kenz): move colors from other pages to this file for consistency.

/// Memory heat map blueish color incremental colors from Blue 100 to Blue 900.
Color memoryHeatMapLightColor = const Color(0xFFBBDEFB); // Material BLUE 100
Color memoryHeatMapDarkColor = const Color(0xFF0D47A1); // Material BLUE 900

const mainUiColor = Color(0xFF88B1DE);
const mainRasterColor = Color(0xFF2C5DAA);
const mainUnknownColor = Color(0xFFCAB8E9);
const mainAsyncColor = Color(0xFF80CBC4);

final uiColorPalette = [
  const ColorPair(background: mainUiColor, foreground: Colors.black),
  const ColorPair(background: Color(0xFF6793CD), foreground: Colors.black),
];

final rasterColorPalette = [
  const ColorPair(
    background: mainRasterColor,
    foreground: contrastForegroundWhite,
  ),
  const ColorPair(
    background: Color(0xFF386EB6),
    foreground: contrastForegroundWhite,
  ),
];

// TODO(jacobr): merge this with other color scheme extensions.
extension FlameChartColorScheme on ColorScheme {
  Color get selectedFrameBackgroundColor =>
      isLight ? const Color(0xFFDBDDDD) : const Color(0xFF4E4F4F);

  Color get treeGuidelineColor =>
      isLight ? Colors.black54 : const Color.fromARGB(255, 200, 200, 200);
}

const defaultSelectionForegroundColor = Colors.white;
const defaultSelectionColor = Color(0xFF36C6F4);

const searchMatchColor = Colors.yellow;
final searchMatchColorOpaque = Colors.yellow.withOpacity(0.5);
const activeSearchMatchColor = Colors.orangeAccent;
final activeSearchMatchColorOpaque = Colors.orangeAccent.withOpacity(0.5);

// Teal 200, 400 - see https://material.io/design/color/#tools-for-picking-colors.
const asyncColorPalette = [
  ColorPair(background: mainAsyncColor, foreground: Colors.black),
  ColorPair(background: Color(0xFF26A69A), foreground: Colors.black),
];

// Slight variation on Deep purple 100, 300 - see https://material.io/design/color/#tools-for-picking-colors.
const unknownColorPalette = [
  ColorPair(background: mainUnknownColor, foreground: Colors.black),
  ColorPair(background: Color(0xFF9D84CA), foreground: Colors.black),
];

const uiJankColor = Color(0xFFF5846B);
const rasterJankColor = Color(0xFFC3595A);
const shaderCompilationColor = ColorPair(
  background: Color(0xFF77102F),
  foreground: contrastForegroundWhite,
);

const treemapIncreaseColor = Color(0xFF3FB549);
const treemapDecreaseColor = Color(0xFF77102F);

const tableIncreaseColor = Color(0xFF73BF43);
const tableDecreaseColor = Color(0xFFEE284F);

const treemapDeferredColor = Color(0xFFC5CAE9);

const appCodeColor = ThemedColorPair(
  background: ThemedColor(
    light: Color(0xFFFA7B17),
    dark: Color(0xFFFCAD70),
  ),
  foreground: ThemedColor.fromSingle(Color(0xFF202124)),
);

const nativeCodeColor = ThemedColorPair(
  background: ThemedColor(
    light: Color(0xFF007B83),
    dark: Color(0xFF72B6C6),
  ),
  foreground: ThemedColor(
    light: Color(0xFFF8F9FA),
    dark: Color(0xFF202124),
  ),
);

const flutterCoreColor = ThemedColorPair(
  background: ThemedColor(
    light: Color(0xFF6864D3),
    dark: Color(0xFF928EF9),
  ),
  foreground: ThemedColor(
    light: Color(0xFFF8F9FA),
    dark: Color(0xFF202124),
  ),
);

const dartCoreColor = ThemedColorPair(
  background: ThemedColor(
    light: Color(0xFF1D649C),
    dark: Color(0xFF6887F7),
  ),
  foreground: ThemedColor(
    light: Color(0xFFF8F9FA),
    dark: Color(0xFF202124),
  ),
);
