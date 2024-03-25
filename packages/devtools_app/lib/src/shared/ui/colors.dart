// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

/// This file holds color constants that are used throughout DevTools.
// TODO(kenz): move colors from other pages to this file for consistency.

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
    foreground: Colors.white,
  ),
  const ColorPair(
    background: Color(0xFF386EB6),
    foreground: Colors.white,
  ),
];

// TODO(jacobr): merge this with other color scheme extensions.
extension FlameChartColorScheme on ColorScheme {
  Color get selectedFrameBackgroundColor =>
      isLight ? const Color(0xFFDBDDDD) : const Color(0xFF4E4F4F);

  Color get treeGuidelineColor =>
      isLight ? Colors.black54 : const Color.fromARGB(255, 200, 200, 200);
}

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
  foreground: Colors.white,
);

const treemapIncreaseColor = Color(0xFF3FB549);
const treemapDecreaseColor = Color(0xFF77102F);

const tableIncreaseColor = Color(0xFF73BF43);
const tableDecreaseColor = Color(0xFFEE284F);

const treemapDeferredColor = Color(0xFFBDBDBD);

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

extension SyntaxHighlightingExtension on ColorScheme {
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
}

// TODO(kenz): try to get rid of these colors and replace with something from
// the light and dark DevTools color schemes.
extension DevToolsColorExtension on ColorScheme {
  // TODO(jacobr): replace this with Theme.of(context).scaffoldBackgroundColor, but we use
  // this in places where we do not have access to the context.
  // remove.
  // TODO(kenz): get rid of this.
  Color get defaultBackgroundColor =>
      isLight ? Colors.grey[50]! : const Color(0xFF1B1B1F);

  Color get grey => const Color.fromARGB(255, 128, 128, 128);
  Color get green =>  isLight ? const Color(0xFF006B5F)  :const Color(0xFF54DBC8);

  Color get overlayShadowColor => const Color.fromRGBO(0, 0, 0, 0.5);
  Color get deeplinkUnavailableColor => const Color(0xFFFE7C04);
  Color get deeplinkTableHeaderColor => isLight ? Colors.white : Colors.black;
}
