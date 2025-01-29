// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_panel.dart';
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

/// To run, use the "standalone_ui/property_editor_sidebar" launch configuration with the
/// `devtools/packages/` folder open in VS Code, or run:
///
/// flutter run -t test/test_infra/scenes/standalone_ui/property_editor_sidebar.stager_app.g.dart -d chrome
class PropertyEditorSidebarScene extends Scene {
  @override
  Widget build(BuildContext context) {
    return const _PropertyEditorSidebar();
  }

  @override
  String get title => '$PropertyEditorSidebarScene';

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
  }
}

class _PropertyEditorSidebar extends StatefulWidget {
  const _PropertyEditorSidebar();

  @override
  State<_PropertyEditorSidebar> createState() => _PropertyEditorState();
}

class _PropertyEditorState extends State<_PropertyEditorSidebar> {
  Stream<String>? clientLog;
  DartToolingDaemon? clientDtd;
  SimulatedEditor? editor;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return IdeThemedMaterialApp(
      home: Scaffold(
        body:
            clientLog != null && clientDtd != null && editor != null
                ? MockEditorWidget(
                  editor: editor!,
                  clientLog: clientLog!,
                  child: PropertyEditorPanel(clientDtd!),
                )
                : _DtdUriForm(
                  onSaved: _connectToDtd,
                  formKey: GlobalKey<FormState>(),
                ),
      ),
    );
  }

  Future<void> _connectToDtd(String? dtdUri) async {
    if (dtdUri == null) return;
    final uri = Uri.parse(dtdUri);
    final connection = await createLoggedWebSocketChannel(uri);
    setState(() {
      clientLog = connection.log;
      clientDtd = DartToolingDaemon.fromStreamChannel(connection.channel);
      editor = SimulatedEditor(uri);
    });
  }
}

class _DtdUriForm extends StatelessWidget {
  const _DtdUriForm({required this.onSaved, required this.formKey});

  final void Function(String?) onSaved;
  final GlobalKey<FormState> formKey;

  // We assume a DTD is available on 8500. There's a VS Code task that
  // launches this as part of the standalone_ui/editor_sidebar config.
  static const _defaultDtdUri = 'ws://127.0.0.1:8500/';

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Connect to DTD:'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextFormField(
                  initialValue: _defaultDtdUri,
                  style: Theme.of(context).fixedFontStyle,
                  onSaved: onSaved,
                ),
              ),
              Flexible(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    formKey.currentState?.save();
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
