// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../utils/utils.dart';
import 'theme.dart';

export '_ide_theme_desktop.dart'
    if (dart.library.js_interop) '_ide_theme_web.dart';

final _log = Logger('ide_theme');

/// IDE-supplied theming.
final class IdeTheme {
  IdeTheme({
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = unscaledDefaultFontSize,
    this.embed = false,
    this.isDarkMode = true,
  });

  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;
  final bool embed;
  final bool isDarkMode;

  double get fontSizeFactor => fontSize / unscaledDefaultFontSize;
}

extension type IdeThemeQueryParams(Map<String, String?> params) {
  Color? get backgroundColor => _tryParseColor(params[backgroundColorKey]);

  Color? get foregroundColor => _tryParseColor(params[foregroundColorKey]);

  double get fontSize =>
      _tryParseDouble(params[fontSizeKey]) ?? unscaledDefaultFontSize;

  bool get embed => params[embedKey] == 'true';

  bool get darkMode => params[devToolsThemeKey] != lightThemeValue;

  static const backgroundColorKey = 'backgroundColor';
  static const foregroundColorKey = 'foregroundColor';
  static const fontSizeKey = 'fontSize';
  static const embedKey = 'embed';
  static const devToolsThemeKey = 'theme';
  static const lightThemeValue = 'light';

  Color? _tryParseColor(String? input) {
    if (input == null) return null;

    try {
      return parseCssHexColor(input);
    } catch (e, st) {
      // The user can manipulate the query string so if the value is invalid
      // print the value but otherwise continue.
      _log.warning(
        'Failed to parse "$input" as a color from the querystring, ignoring: $e',
        e,
        st,
      );
      return null;
    }
  }

  double? _tryParseDouble(String? input) {
    try {
      if (input != null) {
        return double.parse(input);
      }
    } catch (e, st) {
      // The user can manipulate the query string so if the value is invalid
      // print the value but otherwise continue.
      _log.warning(
        'Failed to parse "$input" as a double from the querystring, ignoring: $e',
        e,
        st,
      );
    }
    return null;
  }
}
