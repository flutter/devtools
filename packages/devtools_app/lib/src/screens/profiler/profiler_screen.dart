// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui/icons.dart';
import '../../shared/ui/vm_flag_widgets.dart';
import '../../shared/utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler.dart';
import 'cpu_profiler_controller.dart';
import 'panes/controls/profiler_controls.dart';
import 'profiler_screen_controller.dart';

class ProfilerScreen extends Screen {
  ProfilerScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          title: ScreenMetaData.cpuProfiler.title,
          icon: Octicons.dashboard,
        );

  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');
  @visibleForTesting
  static const recordingStatusKey = Key('Recording Status');

  static final id = ScreenMetaData.cpuProfiler.id;

  @override
  String get docPageId => id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) => const ProfilerScreenBody();
}

class ProfilerScreenBody extends StatefulWidget {
  const ProfilerScreenBody();

  @override
  _ProfilerScreenBodyState createState() => _ProfilerScreenBodyState();
}

class _ProfilerScreenBodyState extends State<ProfilerScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<ProfilerScreenController, ProfilerScreenBody> {
  bool recording = false;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    ga.screen(ProfilerScreen.id);
    addAutoDisposeListener(offlineController.offlineMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, ProfilerScreen.id);
    if (!initController()) return;

    cancelListeners();

    addAutoDisposeListener(controller.loadingOfflineData);

    addAutoDisposeListener(controller.recordingNotifier, () {
      setState(() {
        recording = controller.recordingNotifier.value;
      });
    });

    addAutoDisposeListener(
      controller.cpuProfilerController.processingNotifier,
      () {
        setState(() {
          processing =
              controller.cpuProfilerController.processingNotifier.value;
        });
      },
    );

    addAutoDisposeListener(
      controller.cpuProfilerController.transformer.progressNotifier,
      () {
        setState(() {
          processingProgress = controller
              .cpuProfilerController.transformer.progressNotifier.value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (offlineController.offlineMode.value)
      return _buildProfilerScreenBody(controller);
    return ValueListenableBuilder<Flag>(
      valueListenable: controller.cpuProfilerController.profilerFlagNotifier!,
      builder: (context, profilerFlag, _) {
        return profilerFlag.valueAsString == 'true'
            ? _buildProfilerScreenBody(controller)
            : CpuProfilerDisabled(controller.cpuProfilerController);
      },
    );
  }

  Widget _buildProfilerScreenBody(ProfilerScreenController controller) {
    return FutureBuilder(
      future: controller.initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller.loadingOfflineData.value) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          );
        }

        const emptyAppStartUpProfileView = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'There are no app start up samples available.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: denseSpacing),
              Text(
                'To avoid this, try to open the DevTools CPU profiler '
                'sooner after starting your app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
        final emptyProfileView = Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              text: 'No CPU samples recorded.',
            ),
          ),
        );

        return Column(
          children: [
            ProfilerScreenControls(
              controller: controller,
              recording: recording,
              processing: processing,
              offline: offlineController.offlineMode.value,
            ),
            const SizedBox(height: intermediateSpacing),
            Expanded(
              child: ValueListenableBuilder<CpuProfileData?>(
                valueListenable: controller.cpuProfilerController.dataNotifier,
                builder: (context, cpuProfileData, _) {
                  if (cpuProfileData ==
                          CpuProfilerController.baseStateCpuProfileData ||
                      cpuProfileData == null) {
                    return _buildRecordingInfo();
                  }
                  if (cpuProfileData ==
                      CpuProfilerController.emptyAppStartUpProfile) {
                    return emptyAppStartUpProfileView;
                  }
                  if (cpuProfileData.isEmpty &&
                      !controller.cpuProfilerController.isFilterActive) {
                    return emptyProfileView;
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
      },
    );
  }

  Widget _buildRecordingInfo() {
    return RecordingInfo(
      instructionsKey: ProfilerScreen.recordingInstructionsKey,
      recordingStatusKey: ProfilerScreen.recordingStatusKey,
      recording: recording,
      processing: processing,
      progressValue: processingProgress,
      recordedObject: 'CPU samples',
    );
  }
}

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
          screenId: ProfilerScreen.id,
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
