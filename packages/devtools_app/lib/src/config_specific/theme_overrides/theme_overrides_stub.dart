// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Environment-specific theme overrides, for example IDE-provided
/// theming for embedded mode.
class ThemeOverrides {
  ThemeOverrides({this.backgroundColor, this.foregroundColor, this.fontSize});

  factory ThemeOverrides.load() => ThemeOverrides();

  Color backgroundColor;
  Color foregroundColor;
  double fontSize;
}
