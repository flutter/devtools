// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/primitives/listenable.dart';
import '../shared/primitives/utils.dart';
import '../shared/screen.dart';
import 'embedded/controller.dart';
import 'embedded/view.dart';
import 'extension_screen_controls.dart';

class ExtensionScreen extends Screen {
  ExtensionScreen(this.extensionConfig)
      : super.conditional(
          // TODO(kenz): we may need to ensure this is a unique id.
          id: '${extensionConfig.name}_ext',
          title: extensionConfig.name.toSentenceCase(),
          icon: extensionConfig.icon,
          // TODO(kenz): support static DevTools extensions.
          requiresConnection: true,
        );

  final DevToolsExtensionConfig extensionConfig;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) =>
      _ExtensionScreenBody(extensionConfig: extensionConfig);
}

class _ExtensionScreenBody extends StatefulWidget {
  const _ExtensionScreenBody({required this.extensionConfig});

  final DevToolsExtensionConfig extensionConfig;

  @override
  State<_ExtensionScreenBody> createState() => __ExtensionScreenBodyState();
}

class __ExtensionScreenBodyState extends State<_ExtensionScreenBody> {
  EmbeddedExtensionController? extensionController;

  @override
  void initState() {
    super.initState();
    extensionController =
        createEmbeddedExtensionController(widget.extensionConfig)..init();
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
      extensionController =
          createEmbeddedExtensionController(widget.extensionConfig)..init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExtensionView(
      controller: extensionController!,
      extension: widget.extensionConfig,
    );
  }
}

class ExtensionView extends StatelessWidget {
  const ExtensionView({
    super.key,
    required this.controller,
    required this.extension,
  });

  final EmbeddedExtensionController controller;

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EmbeddedExtensionHeader(
          extension: extension,
          onForceReload: controller.forceReload,
        ),
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: ValueListenableBuilder<ExtensionEnabledState>(
            valueListenable: extensionService.enabledStateListenable(
              extension.name,
            ),
            builder: (context, activationState, _) {
              if (activationState == ExtensionEnabledState.enabled) {
                return KeepAliveWrapper(
                  child: Center(
                    child: EmbeddedExtensionView(controller: controller),
                  ),
                );
              }
              return EnableExtensionPrompt(
                extension: controller.extensionConfig,
              );
            },
          ),
        ),
      ],
    );
  }
}

extension ExtensionConfigExtension on DevToolsExtensionConfig {
  IconData get icon => IconData(
        materialIconCodePoint,
        fontFamily: 'MaterialIcons',
      );
}
