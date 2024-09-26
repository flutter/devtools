// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/shared.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/utils.dart';
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
  InspectorScreenSwitcherState createState() => InspectorScreenSwitcherState();
}

class InspectorScreenSwitcherState extends State<InspectorScreenSwitcher>
    with
        ProvidedControllerMixin<InspectorScreenController,
            InspectorScreenSwitcher> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: preferences.inspector.inspectorV2Enabled,
      builder: (context, v2Enabled, _) {
        if (v2Enabled) {
          return v2.InspectorScreenBody(
            controller: controller.inspectorControllerV2,
          );
        }

        return legacy.InspectorScreenBody(
          controller: controller.inspectorControllerLegacy,
        );
      },
    );
  }
}
