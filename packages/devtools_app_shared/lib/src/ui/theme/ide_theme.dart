// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
    this.embedMode = EmbedMode.none,
    bool? isDarkMode,
  }) : _isDarkMode = isDarkMode;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final EmbedMode embedMode;
  final bool? _isDarkMode;

  bool get embedded => embedMode.embedded;

  bool get isDarkMode => _isDarkMode ?? useDarkThemeAsDefault;

  /// Whether the IDE specified the DevTools color theme.
  ///
  /// If this returns false, that means the
  /// [IdeThemeQueryParams.devToolsThemeKey] query parameter was not passed to
  /// DevTools from the IDE.
  bool get ideSpecifiedTheme => _isDarkMode != null;
}

extension type IdeThemeQueryParams(Map<String, String?> params) {
  Color? get backgroundColor =>
      tryParseColor(params[backgroundColorKey], logger: _log);

  Color? get foregroundColor =>
      tryParseColor(params[foregroundColorKey], logger: _log);

  EmbedMode get embedMode => EmbedMode.fromArgs(params);

  bool get darkMode => params[devToolsThemeKey] != lightThemeValue;

  static const backgroundColorKey = 'backgroundColor';
  static const foregroundColorKey = 'foregroundColor';
  static const devToolsThemeKey = 'theme';
  static const lightThemeValue = 'light';
  static const darkThemeValue = 'dark';
}
