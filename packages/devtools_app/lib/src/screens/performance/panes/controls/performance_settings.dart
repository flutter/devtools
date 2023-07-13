// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../performance_controller.dart';
import '../flutter_frames/flutter_frames_controller.dart';

class PerformanceSettingsDialog extends StatelessWidget {
  const PerformanceSettingsDialog(this.controller, {super.key});

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: const DialogTitleText('Performance Settings'),
      includeDivider: false,
      content: SizedBox(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
              FlutterSettings(
                flutterFramesController: controller.flutterFramesController,
              ),
              const SizedBox(height: denseSpacing),
            ],
            CheckboxSetting(
              notifier:
                  controller.timelineEventsController.useLegacyTraceViewer,
              title: 'Use legacy trace viewer',
              onChanged: controller
                  .timelineEventsController.toggleUseLegacyTraceViewer,
            ),
          ],
        ),
      ),
      actions: const [
        DialogCloseButton(),
      ],
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
          notifier: flutterFramesController.badgeTabForJankyFrames
              as ValueNotifier<bool?>,
          title: 'Badge Performance tab when Flutter UI jank is detected',
        ),
      ],
    );
  }
}
