// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../ui/theme.dart';

TextStyle unimportant(ColorScheme colorScheme) => TextStyle(
    color: colorScheme.isLight ? Colors.grey.shade500 : Colors.grey.shade600);
const regular = TextStyle();
TextStyle warning(ColorScheme colorScheme) => TextStyle(
    color:
        colorScheme.isLight ? Colors.orange.shade900 : Colors.orange.shade400);
TextStyle error(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.isLight ? Colors.red.shade500 : Colors.red.shade400,
    );
TextStyle link(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.isLight ? Colors.blue.shade700 : Colors.blue.shade300,
      decoration: TextDecoration.underline,
    );

TextStyle regularBold(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.defaultForeground,
      fontWeight: FontWeight.w700,
    );
TextStyle regularItalic(ColorScheme colorScheme) => TextStyle(
      color: colorScheme.defaultForeground,
      fontStyle: FontStyle.italic,
    );
TextStyle unimportantItalic(ColorScheme colorScheme) =>
    unimportant(colorScheme).merge(const TextStyle(
      fontStyle: FontStyle.italic,
    ));
