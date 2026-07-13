// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import 'accessibility_controller.dart';

/// A screen that displays accessibility information.
class AccessibilityScreen extends Screen {
  AccessibilityScreen() : super.fromMetaData(ScreenMetaData.accessibility);

  static final id = ScreenMetaData.accessibility.id;

  @override
  Widget buildScreenBody(BuildContext context) =>
      const AccessibilityScreenBody();
}

class AccessibilityScreenBody extends StatefulWidget {
  const AccessibilityScreenBody({super.key});

  @override
  State<AccessibilityScreenBody> createState() =>
      _AccessibilityScreenBodyState();
}

class _AccessibilityScreenBodyState extends State<AccessibilityScreenBody>
    with AutoDisposeMixin {
  late AccessibilityController controller;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<AccessibilityController>();
  }

  @override
  Widget build(BuildContext context) {
    final splitAxis = _splitAxisFor(context);
    return SplitPane(
      axis: splitAxis,
      initialFractions: const [0.6, 0.4],
      children: const [
        AccessibilitySemanticsTreePane(),
        AccessibilityOverridesPane(),
      ],
    );
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width > 1000 ? Axis.horizontal : Axis.vertical;
  }
}

/// A pane that displays the semantics tree of the connected app.
class AccessibilitySemanticsTreePane extends StatelessWidget {
  const AccessibilitySemanticsTreePane({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Semantics Tree')),
      child: CenteredMessage(
        message:
            'Accessibility semantics tree placeholder.\n'
            '// TODO(hannah-hyj): Implement semantics tree view and details explorer.',
      ),
    );
  }
}

/// A pane that displays the accessibility overrides controls.
class AccessibilityOverridesPane extends StatelessWidget {
  const AccessibilityOverridesPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Accessibility Overrides')),
      child: CenteredMessage(
        message:
            'Accessibility overrides placeholder.\n'
            '// TODO(hannah-hyj): Implement setting overrides (brightness, text scale, bold text, screen reader, high contrast).',
      ),
    );
  }
}
