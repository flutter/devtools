// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';

/// IDE-supplied theming.
class IdeTheme {
  IdeTheme({this.backgroundColor, this.foregroundColor, this.fontSize});

  factory IdeTheme.load() => IdeTheme();

  Color backgroundColor;
  Color foregroundColor;
  double fontSize;
}
