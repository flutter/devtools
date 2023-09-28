// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../utils/globals.dart';
import 'theme/ide_theme.dart';

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
