// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'ide_theme.dart';
import 'theme.dart';

/// Change this value to ensure your changes work well with custom font sizes.
bool debugLargeFontSize = false;

/// Load any IDE-supplied theming.
IdeTheme getIdeTheme() =>
    IdeTheme(fontSize: debugLargeFontSize ? 40.0 : unscaledDefaultFontSize);
