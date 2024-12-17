// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
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

  bool isGreyscale() {
    final averageChannel = (r + g + b) / 3;
    final lowestChannel = math.max(0, averageChannel - 0.05);
    final highestChannel = math.min(1, averageChannel + 0.05);
    return [
      r,
      g,
      b
    ].every((channel) => channel >= lowestChannel && channel <= highestChannel);
  }

  Color accent() {
    if (isGreyscale()) return this;

    final sorted = [r, g, b]..sort();
    return Color.from(
        alpha: a,
        red: _calculateAccentChannel(r, sorted),
        blue: _calculateAccentChannel(b, sorted),
        green: _calculateAccentChannel(g, sorted));
  }

  double _calculateAccentChannel(double channel, List<double> sorted) {
    if (sorted.first == channel) return (sorted.first + sorted.last) / 1.5;
    if (sorted.last == channel) return (sorted.first + sorted.last) / 2.5;
    return channel;
  }
}
