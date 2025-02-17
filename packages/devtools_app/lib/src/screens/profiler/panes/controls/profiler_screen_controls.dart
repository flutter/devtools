// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/framework/screen.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/ui/common_widgets.dart';
import '../../../../shared/ui/file_import.dart';
import '../../../../shared/ui/vm_flag_widgets.dart';
import '../../profiler_screen_controller.dart';

class ProfilerScreenControls extends StatelessWidget {
  const ProfilerScreenControls({
    super.key,
    required this.controller,
    required this.recording,
    required this.processing,
    required this.offline,
  });

  final ProfilerScreenController controller;

  final bool recording;

  final bool processing;

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return OfflineAwareControls(
      gaScreen: gac.cpuProfiler,
      controlsBuilder: (offline) {
        if (offline) return const SizedBox.shrink();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PrimaryControls(controller: controller, recording: recording),
            const SizedBox(width: defaultSpacing),
            _SecondaryControls(
              controller: controller,
              profilerBusy: recording || processing,
            ),
          ],
        );
      },
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({required this.controller, required this.recording});

  static const _primaryControlsMinIncludeTextWidth = 1170.0;

  final ProfilerScreenController controller;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StartStopRecordingButton(
          recording: recording,
          gaScreen: gac.cpuProfiler,
          gaSelection: recording ? gac.stop : gac.record,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed:
              recording ? controller.stopRecording : controller.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        ClearButton(
          gaScreen: gac.cpuProfiler,
          gaSelection: gac.clear,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: recording ? null : controller.clear,
        ),
      ],
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({
    required this.controller,
    required this.profilerBusy,
  });

  static const _profilingControlsMinScreenWidthForText = 930.0;

  final ProfilerScreenController controller;

  final bool profilerBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceConnection
            .serviceManager
            .connectedApp!
            .isFlutterNativeAppNow)
          GaDevToolsButton(
            icon: Icons.timer,
            label: 'Profile app start up',
            tooltip:
                'Load all Dart CPU samples that occurred before \n'
                'the first Flutter frame was drawn (if available)',
            tooltipPadding: const EdgeInsets.all(denseSpacing),
            gaScreen: gac.cpuProfiler,
            gaSelection: gac.CpuProfilerEvents.profileAppStartUp.name,
            minScreenWidthForTextBeforeScaling:
                _profilingControlsMinScreenWidthForText,
            onPressed:
                !profilerBusy
                    ? controller.cpuProfilerController.loadAppStartUpProfile
                    : null,
          ),
        const SizedBox(width: denseSpacing),
        RefreshButton(
          label: 'Load all CPU samples',
          tooltip:
              'Load all CPU samples for the connected app. This is the data \ncollected by the VM and is limited by the available buffer space.',
          gaScreen: gac.cpuProfiler,
          gaSelection: gac.CpuProfilerEvents.loadAllCpuSamples.name,
          minScreenWidthForTextBeforeScaling:
              _profilingControlsMinScreenWidthForText,
          onPressed:
              !profilerBusy
                  ? controller.cpuProfilerController.loadAllSamples
                  : null,
        ),
        const SizedBox(width: denseSpacing),
        CpuSamplingRateDropdown(
          screenId: gac.cpuProfiler,
          profilePeriodFlagNotifier:
              controller.cpuProfilerController.profilePeriodFlag!,
        ),
        const SizedBox(width: denseSpacing),
        OpenSaveButtonGroup(
          screenId: ScreenMetaData.cpuProfiler.id,
          onSave:
              !profilerBusy &&
                      controller.cpuProfileData != null &&
                      controller.cpuProfileData?.isEmpty == false
                  ? (_) => _exportPerformance()
                  : null,
        ),
      ],
    );
  }

  void _exportPerformance() {
    controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
  }
}
