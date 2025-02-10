// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/editor_client.dart';
import '../../../shared/ui/common_widgets.dart';
import 'property_editor_controller.dart';
import 'property_editor_view.dart';

/// The side panel for the Property Editor.
class PropertyEditorPanel extends StatefulWidget {
  const PropertyEditorPanel(this.dtd, {super.key});

  final DartToolingDaemon dtd;

  @override
  State<PropertyEditorPanel> createState() => _PropertyEditorPanelState();
}

class _PropertyEditorPanelState extends State<PropertyEditorPanel> {
  _PropertyEditorPanelState();

  Future<EditorClient>? _editor;
  PropertyEditorController? _propertyEditorController;

  @override
  void initState() {
    super.initState();

    final editor = EditorClient(widget.dtd);
    ga.screen(gac.PropertyEditorSidebar.id);
    unawaited(
      _editor = editor.initialized.then((_) {
        _propertyEditorController = PropertyEditorController(editor);
        return editor;
      }),
    );
  }

  @override
  void dispose() {
    _propertyEditorController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FutureBuilder(
        future: _editor,
        builder:
            (context, snapshot) => switch ((
              snapshot.connectionState,
              snapshot.data,
            )) {
              (ConnectionState.done, final editor?) =>
                _PropertyEditorConnectedPanel(
                  editor,
                  controller: _propertyEditorController!,
                ),
              _ => const CenteredCircularProgressIndicator(),
            },
      ),
    );
  }
}

/// The property editor panel shown once we know an editor is available.
class _PropertyEditorConnectedPanel extends StatefulWidget {
  const _PropertyEditorConnectedPanel(this.editor, {required this.controller});

  final EditorClient editor;
  final PropertyEditorController controller;

  @override
  State<_PropertyEditorConnectedPanel> createState() =>
      _PropertyEditorConnectedPanelState();
}

class _PropertyEditorConnectedPanelState
    extends State<_PropertyEditorConnectedPanel>
    with AutoDisposeMixin {
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            denseSpacing,
            defaultSpacing,
            defaultSpacing, // Additional right padding for scroll bar.
            defaultSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [PropertyEditorView(controller: widget.controller)],
          ),
        ),
      ),
    );
  }
}
