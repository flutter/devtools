// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import 'accessibility_controller.dart';
import 'overrides_pane.dart';
import 'semantics_tree_pane.dart';

export 'overrides_pane.dart';
export 'semantics_tree_pane.dart';

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
