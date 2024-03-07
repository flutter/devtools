// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serviceConnection
              .serviceManager.connectedApp!.isFlutterAppNow!) ...[
            FlutterSettings(
              flutterFramesController: controller.flutterFramesController,
            ),
          ],
          // TODO(kenz): add a setting here to toggle whether we request the
          // perfetto vm timeline with CPU samples. This has performance
          // implications. See https://github.com/dart-lang/sdk/issues/55137.
        ],
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
