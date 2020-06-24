// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../ui/theme.dart';

TextStyle get unimportant => TextStyle(
      color: ThemedColor(Colors.grey.shade500, Colors.grey.shade600).toColor(),
    );
const regular = TextStyle();
TextStyle get warning => TextStyle(
      color:
          ThemedColor(Colors.orange.shade900, Colors.orange.shade400).toColor(),
    );
TextStyle get error => TextStyle(
      color: ThemedColor(Colors.red.shade500, Colors.red.shade400).toColor(),
    );
TextStyle get link => TextStyle(
      color: ThemedColor(Colors.blue.shade700, Colors.blue.shade300).toColor(),
      decoration: TextDecoration.underline,
    );

TextStyle get regularBold => TextStyle(
      color: defaultForeground.toColor(),
      fontWeight: FontWeight.w700,
    );
TextStyle get regularItalic => TextStyle(
      color: defaultForeground.toColor(),
      fontStyle: FontStyle.italic,
    );
final unimportantItalic = unimportant.merge(const TextStyle(
  fontStyle: FontStyle.italic,
));

/// Pretty names for common text styles to make it easier to debug output
/// containing these names.
final Map<TextStyle, String> debugStyleNames = {
  unimportant: 'grayed',
  regular: '',
  warning: 'warning',
  error: 'error',
  link: 'link',
  regularBold: 'bold',
  regularItalic: 'italic',
};
