// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../shared/embed_mode.dart';
import '../ui_utils.dart';
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
    this.embedMode = EmbedMode.none,
    bool? isDarkMode,
  }) : _isDarkMode = isDarkMode;

  Color? backgroundColor;
  Color? foregroundColor;
  double fontSize;
  final EmbedMode embedMode;
  bool? _isDarkMode;

  double get fontSizeFactor => fontSize / unscaledDefaultFontSize;

  bool get embedded => embedMode.embedded;

  bool get isDarkMode => _isDarkMode ?? useDarkThemeAsDefault;

  set isDarkMode(bool newIsDarkMode) => _isDarkMode = newIsDarkMode;

  /// Whether the IDE specified the DevTools color theme.
  ///
  /// If this returns false, that means the
  /// [IdeThemeQueryParams.devToolsThemeKey] query parameter was not passed to
  /// DevTools from the IDE.
  bool get ideSpecifiedTheme => _isDarkMode != null;
}

extension type IdeThemeQueryParams(Map<String, String?> params) {
  Color? get backgroundColor => tryParseColor(params[backgroundColorKey], logger: _log);

  Color? get foregroundColor => tryParseColor(params[foregroundColorKey], logger: _log);

  double get fontSize =>
      _tryParseDouble(params[fontSizeKey]) ?? unscaledDefaultFontSize;

  EmbedMode get embedMode => EmbedMode.fromArgs(params);

  bool get darkMode => params[devToolsThemeKey] != lightThemeValue;

  static const backgroundColorKey = 'backgroundColor';
  static const foregroundColorKey = 'foregroundColor';
  static const fontSizeKey = 'fontSize';
  static const devToolsThemeKey = 'theme';
  static const lightThemeValue = 'light';
  static const darkThemeValue = 'dark';

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
