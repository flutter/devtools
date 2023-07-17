// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/primitives/listenable.dart';
import '../shared/primitives/utils.dart';
import '../shared/screen.dart';
import '../shared/theme.dart';
import 'embedded/controller.dart';
import 'embedded/view.dart';
import 'extension_model.dart';

class ExtensionScreen extends Screen {
  ExtensionScreen(this.extensionConfig)
      : super.conditional(
          // TODO(kenz): we may need to ensure this is a unique id.
          id: '${extensionConfig.name}-ext',
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
  late final EmbeddedExtensionController extensionController;

  @override
  void initState() {
    super.initState();
    extensionController = createEmbeddedExtensionController();
  }

  @override
  void dispose() {
    extensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExtensionView(
      controller: extensionController,
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
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        children: [
          EmbeddedExtensionHeader(extension: extension),
          Expanded(
            child: KeepAliveWrapper(
              child: Center(
                child: EmbeddedExtensionView(controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// TODO(kenz): add button to deactivate extension once activate / deactivate
// logic is hooked up.
class EmbeddedExtensionHeader extends StatelessWidget {
  const EmbeddedExtensionHeader({super.key, required this.extension});

  final DevToolsExtensionConfig extension;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extensionName = extension.name.toLowerCase();
    return AreaPaneHeader(
      title: RichText(
        text: TextSpan(
          text: 'package:$extensionName extension',
          style: theme.regularTextStyle.copyWith(fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: ' (v${extension.version})',
              style: theme.subtleTextStyle,
            ),
          ],
        ),
      ),
      includeTopBorder: false,
      roundedTopBorder: false,
      rightPadding: defaultSpacing,
      actions: [
        RichText(
          text: LinkTextSpan(
            link: Link(
              display: 'Report an issue',
              url: extension.issueTrackerLink,
              gaScreenName: gac.extensionScreenId,
              gaSelectedItemDescription:
                  gac.extensionFeedback(extensionName),
            ),
            context: context,
          ),
        ),
      ],
    );
  }
}
