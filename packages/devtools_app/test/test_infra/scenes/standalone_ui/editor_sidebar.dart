// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/flutter_panel.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

import 'editor_service/simulated_editor.dart';
import 'mock_editor_widget.dart';
import 'shared/common_ui.dart';
import 'shared/utils.dart';

/// To run, use the "standalone_ui/editor_sidebar" launch configuration with the
/// `devtools/packages/` folder open in VS Code, or run:
///
/// flutter run -t test/test_infra/scenes/standalone_ui/editor_sidebar.stager_app.g.dart -d chrome
class EditorSidebarScene extends Scene {
  late Stream<String> clientLog;
  late DartToolingDaemon clientDtd;
  late SimulatedEditor editor;

  @override
  Widget build(BuildContext context) {
    return IdeThemedMaterialApp(
      home: Scaffold(
        body: MockEditorWidget(
          editor: editor,
          clientLog: clientLog,
          child: EditorSidebarPanel(clientDtd),
        ),
      ),
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

    // We assume a DTD is available on 8500. There's a VS Code task that
    // launches this as part of the standalone_ui/editor_sidebar config.
    // TODO(dantup): Add a way for the mock editor to set workspace roots so
    //  the extensions parts can work in the sidebar.
    final dtdUri = Uri.parse('ws://127.0.0.1:8500/');
    final connection = await createLoggedWebSocketChannel(dtdUri);
    clientLog = connection.log;
    clientDtd = DartToolingDaemon.fromStreamChannel(connection.channel);
    editor = SimulatedEditor(dtdUri);
  }
}
