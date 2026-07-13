// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
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
      children: [_buildMainContent(), _buildOverridesPane()],
    );
  }

  Widget _buildMainContent() {
    return AnalyticsTabbedView(
      gaScreen: AccessibilityScreen.id,
      tabs: [
        (
          tab: DevToolsTab.create(
            tabName: 'Diagnostics',
            gaPrefix: AccessibilityScreen.id,
          ),
          tabView: _buildDiagnosticsPane(),
        ),
        (
          tab: DevToolsTab.create(
            tabName: 'Semantics Tree',
            gaPrefix: AccessibilityScreen.id,
          ),
          tabView: _buildSemanticsTreePane(),
        ),
      ],
    );
  }

  Axis _splitAxisFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.width > 1000 ? Axis.horizontal : Axis.vertical;
  }

  Widget _buildDiagnosticsPane() {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Accessibility Diagnostics')),
      child: Center(
        child: Text(
          'Accessibility diagnostics placeholder.\n'
          '// TODO(a11y): Implement audit scanning and accessibility violations list.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSemanticsTreePane() {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Semantics Tree')),
      child: Center(
        child: Text(
          'Accessibility semantics tree placeholder.\n'
          '// TODO(a11y): Implement semantics tree view and details explorer.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOverridesPane() {
    return const DevToolsAreaPane(
      header: AreaPaneHeader(title: Text('Accessibility Overrides')),
      child: Center(
        child: Text(
          'Accessibility overrides placeholder.\n'
          '// TODO(a11y): Implement setting overrides (brightness, text scale, bold text, screen reader, high contrast).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
