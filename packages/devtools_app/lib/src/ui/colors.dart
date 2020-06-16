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

// TODO(peterdjlee): Rename mainUiColor to something that more broadly matches where the color is used.
const mainUiColor = Color(0xFF88B1DE);
const mainRasterColor = Color(0xFF2C5DAA);
const mainUnknownColor = Color(0xFFCAB8E9);
const mainAsyncColor = Color(0xFF80CBC4);

final uiColorPalette = [
  mainUiColor,
  const Color(0xFF6793CD),
];

final rasterColorPalette = [
  mainRasterColor,
  const Color(0xFF386EB6),
];

const selectedFrameBackgroundColor =
    ThemedColor(Color(0xFFDBDDDD), Color(0xFF4E4F4F));
const timelineSelectionColor = Color(0xFF36C6F4);

// Teal 200, 400 - see https://material.io/design/color/#tools-for-picking-colors.
const asyncColorPalette = [
  mainAsyncColor,
  Color(0xFF26A69A),
];

// Slight variation on Deep purple 100, 300 - see https://material.io/design/color/#tools-for-picking-colors.
const unknownColorPalette = [
  mainUnknownColor,
  Color(0xFF9D84CA),
];

const uiJankColor = Color(0xFFF5846B);
const rasterJankColor = Color(0xFFC3595A);

const treeGuidelineColor = ThemedColor(
  Colors.black54,
  Color.fromARGB(255, 200, 200, 200),
);
