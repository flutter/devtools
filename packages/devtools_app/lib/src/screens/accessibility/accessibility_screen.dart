// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/tab.dart';
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
        _AccessibilityMainContent(),
        _AccessibilityOverridesPane(),
      ],
    );
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width > 1000 ? Axis.horizontal : Axis.vertical;
  }
}

class _AccessibilityMainContent extends StatelessWidget {
  const _AccessibilityMainContent();

  @override
  Widget build(BuildContext context) {
    return AnalyticsTabbedView(
      gaScreen: AccessibilityScreen.id,
      tabs: [
        (
          tab: DevToolsTab.create(
            tabName: 'Diagnostics',
            gaPrefix: AccessibilityScreen.id,
          ),
          tabView: const _AccessibilityDiagnosticsPane(),
        ),
        (
          tab: DevToolsTab.create(
            tabName: 'Semantics Tree',
            gaPrefix: AccessibilityScreen.id,
          ),
          tabView: const _AccessibilitySemanticsTreePane(),
        ),
      ],
    );
  }
}

class _AccessibilityDiagnosticsPane extends StatelessWidget {
  const _AccessibilityDiagnosticsPane();

  @override
  Widget build(BuildContext context) {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Accessibility Diagnostics')),
      child: CenteredMessage(
        message:
            'Accessibility diagnostics placeholder.\n'
            '// TODO(hannah-hyj): Implement audit scanning and accessibility violations list.',
      ),
    );
  }
}

class _AccessibilitySemanticsTreePane extends StatelessWidget {
  const _AccessibilitySemanticsTreePane();

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

class _AccessibilityOverridesPane extends StatelessWidget {
  const _AccessibilityOverridesPane();

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
