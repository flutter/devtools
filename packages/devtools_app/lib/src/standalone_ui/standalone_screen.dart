// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';
import 'ide_shared/property_editor/property_editor_panel.dart';
import 'vs_code/flutter_panel.dart';

/// "Screens" that are intended for standalone use only, likely for embedding
/// directly in an IDE.
///
/// A standalone screen is one that will only be available at a specific route,
/// meaning that this screen will not be part of DevTools' normal navigation.
/// The only way to access a standalone screen is directly from the url.
enum StandaloneScreenType {
  // TODO(elliette): Add property editor as a standalone screen, see:
  // https://github.com/flutter/devtools/issues/8546
  editorSidebar,
  propertyEditor,
  vsCodeFlutterPanel; // Legacy postMessage version, shows an upgrade message.

  Widget get screen {
    return switch (this) {
      StandaloneScreenType.vsCodeFlutterPanel => const Padding(
        padding: EdgeInsets.all(8.0),
        child: CenteredMessage(
          message:
              'The Flutter sidebar for this SDK requires v3.96 or '
              'newer of the Dart VS Code extension',
        ),
      ),
      StandaloneScreenType.editorSidebar => ValueListenableBuilder(
        // TODO(dantup): Add a timeout here so if dtdManager.connection
        //  doesn't complete after some period we can give some kind of
        //  useful message.
        valueListenable: dtdManager.connection,
        builder: (context, data, _) {
          return _DtdConnectedScreen(
            dtd: data,
            screenProvider: (dtd) => EditorSidebarPanel(dtd),
          );
        },
      ),
      StandaloneScreenType.propertyEditor => ValueListenableBuilder(
        valueListenable: dtdManager.connection,
        builder: (context, data, _) {
          return _DtdConnectedScreen(
            dtd: data,
            screenProvider: (dtd) => PropertyEditorPanel(dtd),
          );
        },
      ),
    };
  }
}

/// Widget that returns a [CenteredCircularProgressIndicator] while it waits for
/// a [DartToolingDaemon] connection.
class _DtdConnectedScreen extends StatelessWidget {
  const _DtdConnectedScreen({required this.dtd, required this.screenProvider});

  final DartToolingDaemon? dtd;
  final Widget Function(DartToolingDaemon) screenProvider;

  @override
  Widget build(BuildContext context) {
    return dtd == null
        ? const CenteredCircularProgressIndicator()
        : screenProvider(dtd!);
  }
}
