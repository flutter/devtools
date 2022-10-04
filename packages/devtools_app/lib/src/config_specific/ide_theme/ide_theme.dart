// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

export 'ide_theme_stub.dart'
    if (dart.library.html) 'ide_theme_web.dart'
    if (dart.library.io) 'ide_theme_desktop.dart';

/// IDE-supplied theming.
class IdeTheme {
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
