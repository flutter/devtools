// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

// Enum-like static classes are ok.
// ignore: avoid_classes_with_only_static_members
class DiagnosticsTextStyles {
  static TextStyle unimportant(ColorScheme colorScheme) => TextStyle(
        color:
            colorScheme.isLight ? Colors.grey.shade500 : Colors.grey.shade600,
      );

  static TextStyle regular(ColorScheme colorScheme) => TextStyle(
        // The font size when not specified seems to be 14, but specify here since we
        // are scaling based on this font size in [IdeTheme].
        fontSize: defaultFontSize,
        color: colorScheme.onSurface,
      );

  static TextStyle warning(ColorScheme colorScheme) => TextStyle(
        color: colorScheme.isLight
            ? Colors.orange.shade900
            : Colors.orange.shade400,
      );

  static TextStyle error(ColorScheme colorScheme) => TextStyle(
        color: colorScheme.error,
      );

  static TextStyle link(ColorScheme colorScheme) => TextStyle(
        color:
            colorScheme.isLight ? Colors.blue.shade700 : Colors.blue.shade300,
        decoration: TextDecoration.underline,
      );

  static const regularBold = TextStyle(
    fontWeight: FontWeight.w700,
  );

  static TextStyle textStyleForLevel(
    DiagnosticLevel level,
    ColorScheme colorScheme,
  ) {
    switch (level) {
      case DiagnosticLevel.hidden:
        return unimportant(colorScheme);
      case DiagnosticLevel.warning:
        return warning(colorScheme);
      case DiagnosticLevel.error:
        return error(colorScheme);
      case DiagnosticLevel.debug:
      case DiagnosticLevel.info:
      case DiagnosticLevel.fine:
      default:
        return regular(colorScheme);
    }
  }
}
