// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

class IdeThemedMaterialApp extends StatelessWidget {
  const IdeThemedMaterialApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: _ideTheme(const VsCodeTheme.light()),
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: _ideTheme(const VsCodeTheme.dark()),
        theme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      ),
      home: home,
    );
  }

  /// Creates an [IdeTheme] using the colours from the mock editor.
  IdeTheme _ideTheme(VsCodeTheme vsCodeTheme) {
    return IdeTheme(
      backgroundColor: vsCodeTheme.editorBackgroundColor,
      foregroundColor: vsCodeTheme.foregroundColor,
      embedMode: EmbedMode.embedOne,
    );
  }
}

/// A basic theme that matches the default colours of VS Code dart/light themes
/// so the mock environment can be displayed in either.
class VsCodeTheme {
  const VsCodeTheme._({
    required this.activityBarBackgroundColor,
    required this.editorBackgroundColor,
    required this.foregroundColor,
    required this.sidebarBackgroundColor,
  });

  const VsCodeTheme.dark()
    : this._(
        activityBarBackgroundColor: const Color(0xFF333333),
        editorBackgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: const Color(0xFFD4D4D4),
        sidebarBackgroundColor: const Color(0xFF252526),
      );

  const VsCodeTheme.light()
    : this._(
        activityBarBackgroundColor: const Color(0xFF2C2C2C),
        editorBackgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF000000),
        sidebarBackgroundColor: const Color(0xFFF3F3F3),
      );

  static VsCodeTheme of(BuildContext context) {
    return Theme.of(context).isDarkTheme
        ? const VsCodeTheme.dark()
        : const VsCodeTheme.light();
  }

  final Color activityBarBackgroundColor;
  final Color editorBackgroundColor;
  final Color foregroundColor;
  final Color sidebarBackgroundColor;
}
