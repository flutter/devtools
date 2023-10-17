// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'theme.dart';

export '_ide_theme_desktop.dart'
    if (dart.library.js_interop) '_ide_theme_web.dart';

/// IDE-supplied theming.
final class IdeTheme {
  IdeTheme({
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = unscaledDefaultFontSize,
    this.embed = false,
  });

  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;
  final bool embed;

  double get fontSizeFactor => fontSize / unscaledDefaultFontSize;
}
