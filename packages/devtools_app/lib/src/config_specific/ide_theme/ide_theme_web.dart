// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:html';

import 'package:flutter/widgets.dart';

import '../../utils.dart';
import '../logger/logger.dart';
import '../url/url.dart';
import 'ide_theme.dart';

/// Load any IDE-supplied theming.
IdeTheme getIdeTheme() {
  final queryParams = loadQueryParams();

  final overrides = IdeTheme(
    backgroundColor: _tryParseColor(queryParams['backgroundColor']),
    foregroundColor: _tryParseColor(queryParams['foregroundColor']),
    fontSize: _tryParseDouble(queryParams['fontSize']),
  );

  // If the environment has provided a background color, set it immediately
  // to avoid a white page until the first Flutter frame is rendered.
  if (overrides.backgroundColor != null) {
    document.body.style.backgroundColor =
        toCssHexColor(overrides.backgroundColor);
  }

  return overrides;
}

Color backgroundColor;
Color foregroundColor;
double fontSize;

Color _tryParseColor(String input) {
  try {
    if (input != null) {
      return parseCssHexColor(input);
    }
  } catch (e) {
    // The user can manipulate the query string so if the value is invalid
    // print the value but otherwise continue.
    log('Failed to parse "$input" as a color from the querystring, ignoring: $e',
        LogLevel.warning);
  }
  return null;
}

double _tryParseDouble(String input) {
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
