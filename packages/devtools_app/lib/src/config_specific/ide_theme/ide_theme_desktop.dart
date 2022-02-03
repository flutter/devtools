// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// @dart=2.9

import 'ide_theme.dart';

/// Change this value to ensure your changes work well with custom font sizes.
bool debugLargeFontSize = false;

/// Load any IDE-supplied theming.
IdeTheme getIdeTheme() => IdeTheme(fontSize: debugLargeFontSize ? 40.0 : null);
