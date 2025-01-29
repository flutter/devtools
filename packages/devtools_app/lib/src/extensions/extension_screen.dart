// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/framework/screen.dart';
import '../shared/globals.dart';
import '../shared/ui/common_widgets.dart';
import 'embedded/controller.dart';
import 'embedded/view.dart';
import 'extension_screen_controls.dart';

class ExtensionScreen extends Screen {
  ExtensionScreen(this.extensionConfig)
    : super.conditional(
        // TODO(kenz): we may need to ensure this is a unique id.
        id: extensionConfig.screenId,
        title: extensionConfig.name,
        icon: extensionConfig.icon,
        requiresConnection:
            // We set this to false all the time when embedded because the
            // available extensions are displayed in a tool window (IntelliJ
            // and Android Studio) with or without any active debug sessions.
            // This prevents a "DevTools Extensions" tool window in IntelliJ
            // and Android Studio that appears to be missing extensions. When
            // a connection is still required to use the extension, messaging
            // for this is provided by the [EmbeddedExtensionView] widget.
            isEmbedded() ? false : extensionConfig.requiresConnection,
      );

  final DevToolsExtensionConfig extensionConfig;

  @override
  Widget buildScreenBody(BuildContext context) =>
      _ExtensionScreenBody(extensionConfig: extensionConfig);
}

class _ExtensionScreenBody extends StatefulWidget {
  const _ExtensionScreenBody({required this.extensionConfig});

  final DevToolsExtensionConfig extensionConfig;

  @override
  State<_ExtensionScreenBody> createState() => _ExtensionScreenBodyState();
}

class _ExtensionScreenBodyState extends State<_ExtensionScreenBody> {
  EmbeddedExtensionController? extensionController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    ga.screen(
      gac.DevToolsExtensionEvents.extensionScreenName(widget.extensionConfig),
    );
    extensionController = createEmbeddedExtensionController(
      widget.extensionConfig,
    )..init();
  }

  @override
  void dispose() {
    extensionController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ExtensionScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extensionConfig != widget.extensionConfig) {
      extensionController?.dispose();
      _init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExtensionView(
      controller: extensionController!,
      ext: widget.extensionConfig,
    );
  }
}

class ExtensionView extends StatelessWidget {
  const ExtensionView({super.key, required this.controller, required this.ext});

  final EmbeddedExtensionController controller;

  final DevToolsExtensionConfig ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmbeddedExtensionHeader(
          ext: ext,
          onForceReload:
              () => controller.postMessage(
                DevToolsExtensionEventType.forceReload,
              ),
        ),
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: ValueListenableBuilder<ExtensionEnabledState>(
            valueListenable: extensionService.enabledStateListenable(ext.name),
            builder: (context, activationState, _) {
              if (activationState == ExtensionEnabledState.enabled) {
                return KeepAliveWrapper(
                  child: Center(
                    child: EmbeddedExtensionView(controller: controller),
                  ),
                );
              }
              return EnableExtensionPrompt(ext: controller.extensionConfig);
            },
          ),
        ),
      ],
    );
  }
}

extension ExtensionConfigExtension on DevToolsExtensionConfig {
  IconData get icon =>
      IconData(materialIconCodePoint, fontFamily: 'MaterialIcons');

  String get screenId => '${name}_ext';
}
