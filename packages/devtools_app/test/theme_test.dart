// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  group('Theme', () {
    ThemeData theme;
    test('can be used without override', () {
      theme = themeFor(isDarkTheme: true, ideTheme: null);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor,
          equals(ThemeData.dark().scaffoldBackgroundColor));

      theme = themeFor(isDarkTheme: false, ideTheme: null);
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor,
          equals(ThemeData.light().scaffoldBackgroundColor));
    });

    test('can be inferred from override background color', () {
      theme = themeFor(
        isDarkTheme: false, // Will be overridden by black BG
        ideTheme: IdeTheme(backgroundColor: Colors.black),
      );
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(Colors.black));

      theme = themeFor(
        isDarkTheme: true, // Will be overridden by white BG
        ideTheme: IdeTheme(backgroundColor: Colors.white),
      );
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor, equals(Colors.white));
    });

    test('will not be inferred for colors that are not dark/light enough', () {
      theme = themeFor(
        isDarkTheme: false, // Will not be overridden - not dark enough
        ideTheme: IdeTheme(backgroundColor: Colors.orange),
      );
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor,
          equals(ThemeData.light().scaffoldBackgroundColor));

      theme = themeFor(
        isDarkTheme: true, // Will not be overridden - not light enough
        ideTheme: IdeTheme(backgroundColor: Colors.orange),
      );
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor,
          equals(ThemeData.dark().scaffoldBackgroundColor));
    });

    test('custom background will not be used if not dark/light enough', () {
      theme = themeFor(
        isDarkTheme: false,
        ideTheme: IdeTheme(backgroundColor: Colors.orange),
      );
      expect(theme.scaffoldBackgroundColor,
          equals(ThemeData.light().scaffoldBackgroundColor));
    });
  });
}
