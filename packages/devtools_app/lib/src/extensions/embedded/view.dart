// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '_view_desktop.dart' if (dart.library.js_interop) '_view_web.dart';
import 'controller.dart';

/// A widget that displays a DevTools extension in an embedded iFrame.
///
/// A DevTools extension is provided by a pub package and is served by the
/// DevTools server when present for a connected application.
///
/// When DevTools is run on Desktop for development, this widget displays a
/// placeholder, since Flutter Desktop does not currently support web views.
class EmbeddedExtensionView extends StatefulWidget {
  const EmbeddedExtensionView({super.key, required this.controller});

  final EmbeddedExtensionController controller;

  @override
  State<EmbeddedExtensionView> createState() => _EmbeddedExtensionViewState();
}

class _EmbeddedExtensionViewState extends State<EmbeddedExtensionView> {
  @override
  void initState() {
    super.initState();
    ga.impression(
      gac.DevToolsExtensionEvents.extensionScreenName(
        widget.controller.extensionConfig,
      ),
      gac.DevToolsExtensionEvents.embeddedExtension.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isEmbedded() &&
        widget.controller.extensionConfig.requiresConnection &&
        !serviceConnection.serviceManager.connectedState.value.connected) {
      return ExtensionRequiresConnection(
        extensionName: widget.controller.extensionConfig.displayName,
      );
    }
    return EmbeddedExtension(controller: widget.controller);
  }
}

@visibleForTesting
class ExtensionRequiresConnection extends StatelessWidget {
  const ExtensionRequiresConnection({super.key, required this.extensionName});

  final String extensionName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The $extensionName extension requires a running applcation.',
            style: theme.boldTextStyle,
          ),
          const SizedBox(height: denseSpacing),
          Text(
            'Start or connect to an active debug session to use this tool.',
            style: theme.regularTextStyle,
          ),
        ],
      ),
    );
  }
}
