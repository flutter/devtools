// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/api/impl/dart_tooling_api.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/flutter_panel.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

import 'editor_service/post_message_fake_editor.dart';
import 'mock_editor_widget.dart';

/// To run, use the "standalone_ui/vs_code" launch configuration with the
/// `devtools/packages/` folder open in VS Code, or run:
///
///   flutter run -t test/test_infra/scenes/standalone_ui/vs_code.stager_app.g.dart --dart-define=enable_experiments=true -d chrome
class VsCodeScene extends Scene {
  late PostMessageFakeEditor editor;
  late PostMessageToolApiImpl api;

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
          child: VsCodePostMessageSidebarPanel(api),
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
  String get title => '$VsCodeScene';

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

    editor = PostMessageFakeEditor();
    api = PostMessageToolApiImpl.rpc(editor.client);
  }
}
