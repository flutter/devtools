// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/feature_flags.dart';
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../inspector/inspector_screen_body.dart' as legacy;
import '../inspector_v2/inspector_screen_body.dart' as v2;
import 'inspector_screen_controller.dart';

class InspectorScreen extends Screen {
  InspectorScreen() : super.fromMetaData(ScreenMetaData.inspector);

  static const minScreenWidthForTextBeforeScaling = 900.0;

  static final id = ScreenMetaData.inspector.id;

  // There is not enough room to safely show the console in the embed view of
  // the DevTools and IDEs have their own consoles.
  @override
  bool showConsole(EmbedMode embedMode) => !embedMode.embedded;

  @override
  String get docPageId => screenId;

  @override
  Widget buildScreenBody(BuildContext context) =>
      const InspectorScreenSwitcher();
}

class InspectorScreenSwitcher extends StatefulWidget {
  const InspectorScreenSwitcher({super.key});

  @override
  State<InspectorScreenSwitcher> createState() =>
      _InspectorScreenSwitcherState();
}

class _InspectorScreenSwitcherState extends State<InspectorScreenSwitcher>
    with AutoDisposeMixin {
  late InspectorScreenController controller;

  bool get shouldShowInspectorV2 =>
      FeatureFlags.inspectorV2 &&
      !preferences.inspector.legacyInspectorEnabled.value;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<InspectorScreenController>();
    addAutoDisposeListener(
      preferences.inspector.legacyInspectorEnabled,
      () async {
        controller.legacyInspectorController.setVisibleToUser(
          !shouldShowInspectorV2,
        );
        await controller.v2InspectorController.setVisibleToUser(
          shouldShowInspectorV2,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: preferences.inspector.legacyInspectorEnabled,
      builder: (context, _, _) {
        if (shouldShowInspectorV2) {
          return v2.InspectorScreenBody(
            controller: controller.v2InspectorController,
          );
        }

        return legacy.InspectorScreenBody(
          controller: controller.legacyInspectorController,
        );
      },
    );
  }
}
