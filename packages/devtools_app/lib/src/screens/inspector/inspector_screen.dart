// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/shared.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../inspector/inspector_screen_body.dart';
import 'inspector_screen_controller.dart';

class InspectorScreen extends Screen {
  InspectorScreen() : super.fromMetaData(ScreenMetaData.inspector);

  static const minScreenWidthForText = 900.0;

  static final id = ScreenMetaData.inspector.id;

  // There is not enough room to safely show the console in the embed view of
  // the DevTools and IDEs have their own consoles.
  @override
  bool showConsole(EmbedMode embedMode) => !embedMode.embedded;

  @override
  bool showAiAssistant() => true;

  @override
  String get docPageId => screenId;

  @override
  Widget buildScreenBody(BuildContext context) {
    final controller = screenControllers.lookup<InspectorScreenController>();
    return InspectorScreenBody(controller: controller.inspectorController);
  }
}
