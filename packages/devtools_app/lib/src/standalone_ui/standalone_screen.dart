// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';
import 'ide_shared/not_connected_overlay.dart';
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
      StandaloneScreenType.editorSidebar => _DtdConnectedScreen(
        dtdManager: dtdManager,
        builder: EditorSidebarPanel.new,
      ),
      StandaloneScreenType.propertyEditor => _DtdConnectedScreen(
        dtdManager: dtdManager,
        builder: PropertyEditorPanel.new,
      ),
    };
  }

  static bool includes(String? screenName) =>
      values.any((value) => value.name == screenName);
}

/// Widget that show progress while connecting to [DartToolingDaemon] and then
/// the result of calling [builder] when a connection is available.
///
/// If the DTD connection is dropped, a reconnecting progress will be shown.
class _DtdConnectedScreen extends StatelessWidget {
  const _DtdConnectedScreen({required this.dtdManager, required this.builder});

  final DTDManager dtdManager;
  final Widget Function(DTDManager) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: dtdManager.connectionState,
      builder: (context, connectionState, child) {
        return ValueListenableBuilder(
          valueListenable: dtdManager.connection,
          builder: (context, connection, _) {
            return Stack(
              children: [
                if (connection != null)
                  // Use a keyed subtree on the connection, so if the connection
                  // changes (eg. we reconnect), we reset the state because it's
                  // not safe to assume the existing state is still valid.
                  //
                  // This allows us to still keep rendering the old state under
                  // the overlay (rather than a blank background) until the
                  // reconnect occurs.
                  KeyedSubtree(
                    key: ValueKey(connection),
                    child: builder(dtdManager),
                  ),
                if (connectionState is! ConnectedDTDState)
                  NotConnectedOverlay(connectionState),
              ],
            );
          },
        );
      },
    );
  }
}
