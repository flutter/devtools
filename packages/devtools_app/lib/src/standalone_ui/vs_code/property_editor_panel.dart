// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../../service/editor/editor_client.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/common_widgets.dart';
import '../ide_shared/property_editor/property_editor_sidebar.dart';

/// The side panel for the Property Editor.
class PropertyEditorSidebarPanel extends StatefulWidget {
  const PropertyEditorSidebarPanel(this.dtd, {super.key});

  final DartToolingDaemon dtd;

  /// Analytics id to track events that come from the property editor sidebar.
  static String get id => 'propertyEditorSidebar';

  @override
  State<PropertyEditorSidebarPanel> createState() =>
      _PropertyEditorSidebarPanelState();
}

class _PropertyEditorSidebarPanelState
    extends State<PropertyEditorSidebarPanel> {
  _PropertyEditorSidebarPanelState();

  Future<EditorClient>? _editor;

  @override
  void initState() {
    super.initState();

    final editor = EditorClient(widget.dtd);
    ga.screen(PropertyEditorSidebarPanel.id);
    unawaited(_editor = editor.initialized.then((_) => editor));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Expanded(
          child: FutureBuilder(
            future: _editor,
            builder:
                (context, snapshot) => switch ((
                  snapshot.connectionState,
                  snapshot.data,
                )) {
                  (ConnectionState.done, final editor?) =>
                    _PropertyEditorConnectedPanel(editor),
                  _ => const CenteredCircularProgressIndicator(),
                },
          ),
      ),
    );
  }
}

/// The property editor panel shown once we know an editor is available.
class _PropertyEditorConnectedPanel extends StatefulWidget {
  const _PropertyEditorConnectedPanel(this.editor);

  final EditorClient editor;

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
        child: const Padding(
          padding: EdgeInsets.fromLTRB(
            denseSpacing,
            defaultSpacing,
            defaultSpacing, // Additional right padding for scroll bar.
            defaultSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [PropertyEditorSidebar()],
          ),
        ),
      ),
    );
  }
}
