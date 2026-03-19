// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import 'accessibility_controller.dart';
import 'accessibility_controls.dart';
import 'accessibility_results.dart';

class AccessibilityScreen extends Screen {
  AccessibilityScreen() : super.fromMetaData(ScreenMetaData.accessibility);

  static final id = ScreenMetaData.accessibility.id;

  @override
  Widget buildScreenBody(BuildContext context) {
    return const AccessibilityScreenBody();
  }
}

class AccessibilityScreenBody extends StatefulWidget {
  const AccessibilityScreenBody({super.key});

  @override
  State<AccessibilityScreenBody> createState() =>
      _AccessibilityScreenBodyState();
}

class _AccessibilityScreenBodyState extends State<AccessibilityScreenBody> {
  late final AccessibilityController controller;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<AccessibilityController>();
  }

  @override
  Widget build(BuildContext context) {
    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.3, 0.7],
      children: const [AccessibilityControls(), AccessibilityResults()],
    );
  }
}
