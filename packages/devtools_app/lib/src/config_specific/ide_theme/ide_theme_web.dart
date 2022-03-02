// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:html';

import 'package:flutter/widgets.dart';

import '../../primitives/utils.dart';
import '../../shared/theme.dart';
import '../logger/logger.dart';
import '../url/url.dart';
import 'ide_theme.dart';

/// Load any IDE-supplied theming.
IdeTheme getIdeTheme() {
  final queryParams = loadQueryParams();

  final overrides = IdeTheme(
    backgroundColor: _tryParseColor(queryParams['backgroundColor']),
    foregroundColor: _tryParseColor(queryParams['foregroundColor']),
    fontSize:
        _tryParseDouble(queryParams['fontSize']) ?? unscaledDefaultFontSize,
    embed: queryParams['embed'] == 'true',
  );

  // If the environment has provided a background color, set it immediately
  // to avoid a white page until the first Flutter frame is rendered.
  if (overrides.backgroundColor != null) {
    document.body!.style.backgroundColor =
        toCssHexColor(overrides.backgroundColor!);
  }

  return overrides;
}

// TODO(polinach): this field seems to be not used, but the app fails without it:
// https://github.com/flutter/devtools/pull/3748#discussion_r817269768
Color? foregroundColor;

Color? _tryParseColor(String? input) {
  if (input == null) return null;

  try {
    return parseCssHexColor(input);
  } catch (e) {
    // The user can manipulate the query string so if the value is invalid
    // print the value but otherwise continue.
    log('Failed to parse "$input" as a color from the querystring, ignoring: $e',
        LogLevel.warning);
    return null;
  }
}

double? _tryParseDouble(String? input) {
  try {
    if (input != null) {
      return double.parse(input);
    }
  } catch (e) {
    // The user can manipulate the query string so if the value is invalid
    // print the value but otherwise continue.
    log('Failed to parse "$input" as a double from the querystring, ignoring: $e',
        LogLevel.warning);
  }
  return null;
}
