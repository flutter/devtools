// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/globals.dart';
import '../../../../shared/ui/common_widgets.dart';
import '../../performance_controller.dart';
import '../flutter_frames/flutter_frames_controller.dart';

class PerformanceSettingsDialog extends StatelessWidget {
  const PerformanceSettingsDialog(this.controller, {super.key});

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    // This settings dialog currently only supports settings for Flutter apps
    // and shouldn't be accessible for Dart CLI programs.
    assert(serviceConnection.serviceManager.connectedApp!.isFlutterAppNow!);
    return DevToolsDialog(
      title: const DialogTitleText('Performance Settings'),
      includeDivider: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlutterSettings(
            flutterFramesController: controller.flutterFramesController,
          ),
        ],
      ),
      actions: const [DialogCloseButton()],
    );
  }
}

class FlutterSettings extends StatelessWidget {
  const FlutterSettings({required this.flutterFramesController, super.key});

  final FlutterFramesController flutterFramesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxSetting(
          notifier:
              flutterFramesController.badgeTabForJankyFrames
                  as ValueNotifier<bool?>,
          title: 'Badge Performance tab when Flutter UI jank is detected',
        ),
      ],
    );
  }
}
