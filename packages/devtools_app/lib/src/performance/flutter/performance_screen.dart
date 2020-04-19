// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/banner_messages.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../performance/performance_controller.dart';
import '../../profiler/cpu_profile_controller.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../profiler/flutter/cpu_profiler.dart';
import '../../ui/flutter/vm_flag_widgets.dart';

class PerformanceScreen extends Screen {
  const PerformanceScreen()
      : super(
          DevToolsScreenType.performance,
          title: 'Performance',
          icon: Octicons.dashboard,
        );

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const recordButtonKey = Key('Record Button');
  @visibleForTesting
  static const stopRecordingButtonKey = Key('Stop Recording Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');
  @visibleForTesting
  static const recordingStatusKey = Key('Recording Status');

  @override
  String get docPageId => 'performance';

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isDartWebAppNow
        ? const PerformanceScreenBody()
        : const DisabledForWebAppMessage();
  }
}

class PerformanceScreenBody extends StatefulWidget {
  const PerformanceScreenBody();

  @override
  _PerformanceScreenBodyState createState() => _PerformanceScreenBodyState();
}

class _PerformanceScreenBodyState extends State<PerformanceScreenBody>
    with AutoDisposeMixin {
  PerformanceController controller;
  bool recording = false;
  bool processing = false;
  double processingProgress = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(
      context,
      DevToolsScreenType.performance,
    );

    final newController = Controllers.of(context).performance;
    if (newController == controller) return;
    controller = newController;

    cancel();
    addAutoDisposeListener(controller.recordingNotifier, () {
      setState(() {
        recording = controller.recordingNotifier.value;
      });
    });
    addAutoDisposeListener(controller.cpuProfilerController.processingNotifier,
        () {
      setState(() {
        processing = controller.cpuProfilerController.processingNotifier.value;
      });
    });
    addAutoDisposeListener(
        controller.cpuProfilerController.transformer.progressNotifier, () {
      setState(() {
        processingProgress =
            controller.cpuProfilerController.transformer.progressNotifier.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Flag>(
      valueListenable: controller.cpuProfilerController.profilerFlagNotifier,
      builder: (context, profilerFlag, _) {
        return profilerFlag.valueAsString == 'true'
            ? _buildPerformanceBody(controller)
            : CpuProfilerDisabled(controller.cpuProfilerController);
      },
    );
  }

  Widget _buildPerformanceBody(PerformanceController controller) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStateControls(controller),
            const ProfileGranularityDropdown(DevToolsScreenType.performance),
          ],
        ),
        Expanded(
          child: ValueListenableBuilder<CpuProfileData>(
            valueListenable: controller.cpuProfilerController.dataNotifier,
            builder: (context, cpuProfileData, _) {
              if (cpuProfileData ==
                      CpuProfilerController.baseStateCpuProfileData ||
                  cpuProfileData == null) {
                return _buildRecordingInfo();
              }
              return CpuProfiler(
                data: cpuProfileData,
                controller: controller.cpuProfilerController,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStateControls(PerformanceController controller) {
    const double includeTextWidth = 600;

    return Row(
      children: [
        recordButton(
          key: PerformanceScreen.recordButtonKey,
          recording: recording,
          includeTextWidth: includeTextWidth,
          onPressed: controller.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: PerformanceScreen.stopRecordingButtonKey,
          recording: recording,
          includeTextWidth: includeTextWidth,
          onPressed: controller.stopRecording,
        ),
        const SizedBox(width: defaultSpacing),
        clearButton(
          key: PerformanceScreen.clearButtonKey,
          includeTextWidth: includeTextWidth,
          onPressed: recording ? null : controller.clear,
        ),
      ],
    );
  }

  Widget _buildRecordingInfo() {
    return recordingInfo(
      instructionsKey: PerformanceScreen.recordingInstructionsKey,
      recordingStatusKey: PerformanceScreen.recordingStatusKey,
      recording: recording,
      processing: processing,
      progressValue: processingProgress,
      recordedObject: 'CPU samples',
    );
  }
}
