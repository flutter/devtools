// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../../../framework/scaffold/report_feedback_button.dart';
import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/editor_client.dart';
import '../../../shared/primitives/query_parameters.dart';
import '../../../shared/ui/common_widgets.dart';
import 'property_editor_controller.dart';
import 'property_editor_view.dart';
import 'reconnecting_overlay.dart';

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
        builder: (context, snapshot) =>
            switch ((snapshot.connectionState, snapshot.data)) {
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
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.shouldReconnect,
      builder: (context, shouldReconnect, _) {
        return Stack(
          children: [
            Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: Column(
                children: [
                  Expanded(
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
                          children: [
                            PropertyEditorView(controller: widget.controller),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const _PropertyEditorFooter(),
                ],
              ),
            ),
            if (shouldReconnect) const ReconnectingOverlay(),
          ],
        );
      },
    );
  }
}

class _PropertyEditorFooter extends StatelessWidget {
  const _PropertyEditorFooter();

  static const _footerHeight = 25.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final documentationLink = _documentationLink();
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).focusColor)),
      ),
      height: _footerHeight,
      padding: const EdgeInsets.symmetric(vertical: densePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (documentationLink != null)
            Padding(
              padding: const EdgeInsets.only(left: denseSpacing),
              child: _DocsLink(
                documentationLink: documentationLink,
                color: colorScheme.onSurface,
              ),
            ),
          const Spacer(),
          ReportFeedbackButton(color: colorScheme.onSurface),
        ],
      ),
    );
  }

  String? _documentationLink() {
    final queryParams = DevToolsQueryParams.load();
    final isEmbedded = queryParams.embedMode.embedded;
    if (!isEmbedded) return null;
    const uriPrefix = 'https://docs.flutter.dev/tools/';
    const uriHash = '#property-editor';
    return '$uriPrefix${queryParams.ide == 'VSCode' ? 'vs-code' : 'android-studio'}$uriHash';
  }
}

class _DocsLink extends StatelessWidget {
  const _DocsLink({required this.documentationLink, required this.color});

  final Color color;
  final String documentationLink;

  @override
  Widget build(BuildContext context) {
    return LinkIconLabel(
      icon: Icons.library_books_outlined,
      link: GaLink(
        display: 'Docs',
        url: documentationLink,
        gaScreenName: gac.PropertyEditorSidebar.id,
        gaSelectedItemDescription: gac.PropertyEditorSidebar.documentationLink,
      ),
      color: color,
    );
  }
}
