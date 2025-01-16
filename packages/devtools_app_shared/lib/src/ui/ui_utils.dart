// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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

/// Utility extension methods to the [Color] class.
extension ColorExtension on Color {
  /// Return a slightly darker color than the current color.
  Color darken([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);
    percent = 1.0 - percent;

    final c = this;
    return Color.from(
      alpha: c.a,
      red: c.r * percent,
      green: c.g * percent,
      blue: c.b * percent,
    );
  }

  /// Return a slightly brighter color than the current color.
  Color brighten([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);

    final c = this;
    return Color.from(
      alpha: c.a,
      red: c.r + ((1.0 - c.r) * percent),
      green: c.g + ((1.0 - c.g) * percent),
      blue: c.b + ((1.0 - c.b) * percent),
    );
  }
}
