// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/flutter/notifications.dart';
import 'package:devtools_app/src/ui/flutter/label.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' as vm;

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/banner_messages.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../profiler/cpu_profile_controller.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../profiler/flutter/cpu_profiler.dart';
import '../../ui/flutter/vm_flag_widgets.dart';
import '../performance_controller.dart';

class PerformanceScreen extends Screen {
  const PerformanceScreen()
      : super(id, title: 'Performance', icon: Octicons.dashboard);

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

  static const id = 'performance';

  @override
  String get docPageId => id;

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

    final newController =
        Provider.of<PerformanceController>(context, listen: false);
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

    // Load offline timeline data if available.
    if (shouldLoadOfflineData()) {
      // This is a workaround to guarantee that DevTools exports are compatible
      // with other trace viewers (catapult, perfetto, chrome://tracing), which
      // require a top level field named "traceEvents". See how timeline data is
      // encoded in [ExportController.encode].
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
    return ValueListenableBuilder<vm.Flag>(
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
        Expanded(
          child: ValueListenableBuilder<CpuProfileData>(
            valueListenable: controller.cpuProfilerController.dataNotifier,
            builder: (context, cpuProfileData, _) {
              if (cpuProfileData ==
                      CpuProfilerController.baseStateCpuProfileData ||
                  cpuProfileData == null) {
                return _buildRecordingInfo();
              }
              print('\n--------------------------------');
              print(cpuProfileData.cpuProfileRoot);
              print('--------------------------------');
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
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          busy: recording,
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
        Container(
          height: Theme.of(context).buttonTheme.height,
          child: OutlineButton(
            onPressed: controller.cpuProfileData != null &&
                    !controller.cpuProfileData.isEmpty
                ? _exportPerformance
                : null,
            child: const MaterialIconLabel(
              Icons.file_download,
              'Export',
              includeTextWidth: _secondaryControlsMinIncludeTextWidth,
            ),
          ),
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

    Notifications.of(context)
        .push('Successfully exported $exportedFile to ~/Downloads directory');
  }

  @override
  FutureOr<void> processOfflineData(CpuProfileData offlineData) async {
    await controller.clear();
    controller.cpuProfilerController.loadOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[PerformanceScreen.id] != null;
  }
}
