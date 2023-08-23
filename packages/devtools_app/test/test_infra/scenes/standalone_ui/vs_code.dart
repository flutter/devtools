// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/flutter_panel.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

import '../../../test_infra/test_data/dart_tooling_api/mock_api.dart';
import 'vs_code_mock_editor.dart';

final _api = MockDartToolingApi();

/// To run, use the "standalone_ui/vs_code" launch configuration with the
/// `devtools/packages/` folder open in VS Code, or run:
///
///   flutter run -t test/test_infra/scenes/standalone_ui/vs_code.stager_app.g.dart --dart-define=enable_experiments=true -d chrome
class VsCodeScene extends Scene {
  late PerformanceController controller;

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
      home: Scaffold(
        body: VsCodeFlutterPanelMockEditor(
          api: _api,
          child: VsCodeFlutterPanel(_api),
        ),
      ),
    );
  }

  /// Creates an [IdeTheme] using the colours from the mock editor.
  IdeTheme _ideTheme(VsCodeTheme vsCodeTheme) {
    return IdeTheme(
      backgroundColor: vsCodeTheme.editorBackgroundColor,
      foregroundColor: vsCodeTheme.foregroundColor,
      embed: true,
    );
  }

  @override
  String get title => '$VsCodeScene';

  @override
  Future<void> setUp() async {
    FeatureFlags.vsCodeSidebarTooling = true;
    setGlobal(IdeTheme, IdeTheme());
  }
}
