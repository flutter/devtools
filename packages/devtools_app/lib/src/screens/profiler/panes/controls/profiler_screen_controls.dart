// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/ui/vm_flag_widgets.dart';
import '../../profiler_screen_controller.dart';

class ProfilerScreenControls extends StatelessWidget {
  const ProfilerScreenControls({
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
    // TODO(kenz): use the [OfflineAwareControls] helper widget.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (offline)
          Padding(
            padding: const EdgeInsets.only(right: defaultSpacing),
            child: ExitOfflineButton(gaScreen: gac.cpuProfiler),
          )
        else ...[
          _PrimaryControls(
            controller: controller,
            recording: recording,
          ),
          const SizedBox(width: defaultSpacing),
          _SecondaryControls(
            controller: controller,
            profilerBusy: recording || processing,
          ),
        ],
      ],
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.controller,
    required this.recording,
  });

  static const _primaryControlsMinIncludeTextWidth = 1170.0;

  final ProfilerScreenController controller;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordButton(
          recording: recording,
          gaScreen: gac.cpuProfiler,
          gaSelection: gac.record,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: controller.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        StopRecordingButton(
          recording: recording,
          gaScreen: gac.cpuProfiler,
          gaSelection: gac.stop,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: controller.stopRecording,
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

  static const _secondaryControlsMinScreenWidthForText = 1170.0;

  static const _profilingControlsMinScreenWidthForText = 875.0;

  final ProfilerScreenController controller;

  final bool profilerBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceManager.connectedApp!.isFlutterNativeAppNow)
          DevToolsButton(
            icon: Icons.timer,
            label: 'Profile app start up',
            tooltip: 'Load all Dart CPU samples that occurred before \n'
                'the first Flutter frame was drawn (if available)',
            tooltipPadding: const EdgeInsets.all(denseSpacing),
            gaScreen: gac.cpuProfiler,
            gaSelection: gac.profileAppStartUp,
            minScreenWidthForTextBeforeScaling:
                _profilingControlsMinScreenWidthForText,
            onPressed: !profilerBusy
                ? controller.cpuProfilerController.loadAppStartUpProfile
                : null,
          ),
        const SizedBox(width: denseSpacing),
        RefreshButton(
          label: 'Load all CPU samples',
          tooltip: 'Load all available CPU samples from the profiler',
          gaScreen: gac.cpuProfiler,
          gaSelection: gac.loadAllCpuSamples,
          minScreenWidthForTextBeforeScaling:
              _profilingControlsMinScreenWidthForText,
          onPressed: !profilerBusy
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
        ExportButton(
          gaScreen: gac.cpuProfiler,
          onPressed: !profilerBusy &&
                  controller.cpuProfileData != null &&
                  controller.cpuProfileData?.isEmpty == false
              ? _exportPerformance
              : null,
          minScreenWidthForTextBeforeScaling:
              _secondaryControlsMinScreenWidthForText,
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
