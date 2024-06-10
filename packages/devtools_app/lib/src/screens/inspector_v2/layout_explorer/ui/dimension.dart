// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'theme.dart';

/// Text widget for displaying width / height.
Widget dimensionDescription(
  TextSpan description,
  bool overflow,
  ColorScheme colorScheme,
) {
  final text = Text.rich(
    description,
    textAlign: TextAlign.center,
    style: overflow
        ? overflowingDimensionIndicatorTextStyle(colorScheme)
        : dimensionIndicatorTextStyle,
    overflow: TextOverflow.ellipsis,
  );
  if (overflow) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: minPadding,
        horizontal: overflowTextHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.overflowBackgroundColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Center(child: text),
    );
  }
  return text;
}
