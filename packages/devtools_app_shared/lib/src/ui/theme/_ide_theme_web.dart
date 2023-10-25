// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../utils/url/url.dart';
import '../../utils/utils.dart';
import 'ide_theme.dart';
import 'theme.dart';

final _log = Logger('ide_theme_web');

/// Load any IDE-supplied theming.
IdeTheme getIdeTheme() {
  final queryParams = loadQueryParams();

  final overrides = IdeTheme(
    backgroundColor: _tryParseColor(queryParams['backgroundColor']),
    foregroundColor: _tryParseColor(queryParams['foregroundColor']),
    fontSize:
        _tryParseDouble(queryParams['fontSize']) ?? unscaledDefaultFontSize,
    embed: queryParams['embed'] == 'true',
    isDarkMode: queryParams['theme'] != 'light',
  );

  // If the environment has provided a background color, set it immediately
  // to avoid a white page until the first Flutter frame is rendered.
  if (overrides.backgroundColor != null) {
    document.body!.style.backgroundColor =
        toCssHexColor(overrides.backgroundColor!);
  }

  return overrides;
}

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
