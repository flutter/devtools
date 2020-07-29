// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/import_export/import_export.dart';
import '../globals.dart';
import '../notifications.dart';
import '../octicons.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profiler.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/vm_flag_widgets.dart';
import 'performance_controller.dart';

class PerformanceScreen extends Screen {
  const PerformanceScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
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
  static const exportButtonKey = Key('Export Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');
  @visibleForTesting
  static const recordingStatusKey = Key('Recording Status');

  static const id = 'performance';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const PerformanceScreenBody();
}

class PerformanceScreenBody extends StatefulWidget {
  const PerformanceScreenBody();

  @override
  _PerformanceScreenBodyState createState() => _PerformanceScreenBodyState();
}

class _PerformanceScreenBodyState extends State<PerformanceScreenBody>
    with
        AutoDisposeMixin,
        OfflineScreenMixin<PerformanceScreenBody, CpuProfileData> {
  static const _primaryControlsMinIncludeTextWidth = 600.0;
  static const _secondaryControlsMinIncludeTextWidth = 1100.0;

  PerformanceController controller;

  bool recording = false;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, PerformanceScreen.id);

    final newController = Provider.of<PerformanceController>(context);
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

    // Load offline performance data if available.
    if (shouldLoadOfflineData()) {
      final performanceJson =
          Map<String, dynamic>.from(offlineDataJson[PerformanceScreen.id]);
      final offlinePerformanceData = CpuProfileData.parse(performanceJson);
      if (!offlinePerformanceData.isEmpty) {
        loadOfflineData(offlinePerformanceData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (offlineMode) return _buildPerformanceBody(controller);
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
    final performanceScreen = Column(
      children: [
        if (!offlineMode) _buildPerformanceControls(),
        const SizedBox(height: denseRowSpacing),
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

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        performanceScreen,
        if (loadingOfflineData)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildPerformanceControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPrimaryStateControls(),
        _buildSecondaryControls(),
      ],
    );
  }

  Widget _buildPrimaryStateControls() {
    return Row(
      children: [
        recordButton(
          key: PerformanceScreen.recordButtonKey,
          recording: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: controller.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: PerformanceScreen.stopRecordingButtonKey,
          recording: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: controller.stopRecording,
        ),
        const SizedBox(width: defaultSpacing),
        clearButton(
          key: PerformanceScreen.clearButtonKey,
          busy: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: controller.clear,
        ),
      ],
    );
  }

  Widget _buildSecondaryControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const ProfileGranularityDropdown(PerformanceScreen.id),
        const SizedBox(width: defaultSpacing),
        ExportButton(
          key: PerformanceScreen.exportButtonKey,
          onPressed: controller.cpuProfileData != null &&
                  !controller.cpuProfileData.isEmpty
              ? _exportPerformance
              : null,
          includeTextWidth: _secondaryControlsMinIncludeTextWidth,
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

  void _exportPerformance() {
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    // TODO(peterdjlee): find a way to push the notification logic into the
    // export controller.
    Notifications.of(context).push(successfulExportMessage(exportedFile));
  }

  @override
  FutureOr<void> processOfflineData(CpuProfileData offlineData) async {
    await controller.cpuProfilerController.transformer.processData(offlineData);
    controller.cpuProfilerController.loadOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[PerformanceScreen.id] != null;
  }
}
