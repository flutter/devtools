// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:logging/logging.dart';

import '../utils/globals.dart';
import '../utils/utils.dart';
import 'theme/ide_theme.dart';

/// Whether DevTools is in embedded mode, as determined by the [ideTheme] parsed
/// from query parameters.
bool isEmbedded() => ideTheme.embedded;

IdeTheme get ideTheme {
  final theme = globals[IdeTheme];
  if (theme == null) {
    throw StateError(
      'The global [IdeTheme] is not set. Please call '
      '`setGlobal(IdeTheme, getIdeTheme())` before you call `runApp`.',
    );
  }
  return theme as IdeTheme;
}

double scaleByFontFactor(double original) {
  return (original * ideTheme.fontSizeFactor).roundToDouble();
}

Color? tryParseColor(String? input, {Logger? logger}) {
  if (input == null) return null;

  try {
    return parseCssHexColor(input);
  } catch (e, st) {
    // The user can manipulate the query string so if the value is invalid
    // print the value but otherwise continue.
    logger?.warning(
      'Failed to parse "$input" as a color from the querystring, ignoring: $e',
      e,
      st,
    );
    return null;
  }
}
