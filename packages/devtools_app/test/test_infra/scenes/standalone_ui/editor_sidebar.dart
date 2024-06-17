// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/flutter_panel.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

import 'editor_service/fake_editor.dart';
import 'mock_editor_widget.dart';

/// To run, use the "standalone_ui/editor_sidebar" launch configuration with the
/// `devtools/packages/` folder open in VS Code, or run:
///
///   flutter run -t test/test_infra/scenes/standalone_ui/editor_sidebar.stager_app.g.dart --dart-define=enable_experiments=true -d chrome
class EditorSidebarScene extends Scene {
  late PerformanceController controller;
  late DartToolingDaemon clientDtd;
  late FakeDtdEditor editor;

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
        body: MockEditorWidget(
          editor: editor,
          child: DtdEditorSidebarPanel(clientDtd),
        ),
      ),
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

  @override
  String get title => '$EditorSidebarScene';

  @override
  Future<void> setUp() async {
    setStagerMode();
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(DTDManager, MockDTDManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());

    // TODO(dantup): Figure out how we can run a DTD here (either real, or a
    // mock that behaves sufficiently like the real one).
    final dtdUri = Uri.parse('ws://127.0.0.1:56934/L4PgEzdLVI8JQxhZ');
    clientDtd = await DartToolingDaemon.connect(dtdUri);
    editor = FakeDtdEditor(await DartToolingDaemon.connect(dtdUri));
    await editor.initialized;
  }
}
