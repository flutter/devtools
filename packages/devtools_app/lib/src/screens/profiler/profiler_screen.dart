// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../analytics/analytics.dart' as ga;
import '../../analytics/analytics_common.dart';
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/import_export/import_export.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/listenable.dart';
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/icons.dart';
import '../../ui/vm_flag_widgets.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler.dart';
import 'profiler_screen_controller.dart';

final profilerScreenSearchFieldKey =
    GlobalKey(debugLabel: 'ProfilerScreenSearchFieldKey');

const iosProfilerWorkaround =
    'https://github.com/flutter/flutter/issues/88466#issuecomment-905830680';

class ProfilerScreen extends Screen {
  const ProfilerScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          title: 'CPU Profiler',
          icon: Octicons.dashboard,
        );

  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');
  @visibleForTesting
  static const recordingStatusKey = Key('Recording Status');

  static const id = 'cpu-profiler';

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
        OfflineScreenMixin<ProfilerScreenBody, CpuProfileData>,
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

    // Load offline profiler data if available.
    if (shouldLoadOfflineData()) {
      final profilerJson = Map<String, dynamic>.from(
        offlineController.offlineDataJson[ProfilerScreen.id],
      );
      final offlineProfilerData = CpuProfileData.parse(profilerJson);
      if (!offlineProfilerData.isEmpty) {
        loadOfflineData(offlineProfilerData);
      }
    }
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
    final emptyAppStartUpProfileView = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
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
    final profilerScreen = Column(
      children: [
        if (!offlineController.offlineMode.value)
          ProfilerScreenControls(
            controller: controller,
            recording: recording,
            processing: processing,
          ),
        const SizedBox(height: denseRowSpacing),
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
              if (cpuProfileData.isEmpty) {
                return emptyProfileView;
              }
              return CpuProfiler(
                data: cpuProfileData,
                controller: controller.cpuProfilerController,
                searchFieldKey: profilerScreenSearchFieldKey,
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
        profilerScreen,
        if (loadingOfflineData)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          ),
      ],
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

  @override
  FutureOr<void> processOfflineData(CpuProfileData offlineData) async {
    await controller.cpuProfilerController.transformer.processData(
      offlineData,
      processId: 'offline data processing',
    );
    controller.cpuProfilerController.loadProcessedData(
      offlineData,
      storeAsUserTagNone: true,
    );
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineController.shouldLoadOfflineData(ProfilerScreen.id);
  }
}

class ProfilerScreenControls extends StatelessWidget {
  const ProfilerScreenControls({
    required this.controller,
    required this.recording,
    required this.processing,
  });

  final ProfilerScreenController controller;

  final bool recording;

  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.controller,
    required this.recording,
  });

  static const _primaryControlsMinIncludeTextWidth = 1050.0;

  final ProfilerScreenController controller;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordButton(
          recording: recording,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: () {
            ga.select(
              analytics_constants.cpuProfiler,
              analytics_constants.record,
            );
            controller.startRecording();
          },
        ),
        const SizedBox(width: denseSpacing),
        StopRecordingButton(
          recording: recording,
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: () {
            ga.select(
              analytics_constants.cpuProfiler,
              analytics_constants.stop,
            );
            controller.stopRecording();
          },
        ),
        const SizedBox(width: denseSpacing),
        ClearButton(
          minScreenWidthForTextBeforeScaling:
              _primaryControlsMinIncludeTextWidth,
          onPressed: recording
              ? null
              : () {
                  ga.select(
                    analytics_constants.cpuProfiler,
                    analytics_constants.clear,
                  );
                  controller.clear();
                },
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

  static const _secondaryControlsMinScreenWidthForText = 1050.0;

  static const _profilingControlsMinScreenWidthForText = 815.0;

  final ProfilerScreenController controller;

  final bool profilerBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceManager.connectedApp!.isFlutterNativeAppNow)
          IconLabelButton(
            icon: Icons.timer,
            label: 'Profile app start up',
            tooltip: 'Load all Dart CPU samples that occurred before \n'
                'the first Flutter frame was drawn (if available)',
            tooltipPadding: const EdgeInsets.all(denseSpacing),
            minScreenWidthForTextBeforeScaling:
                _profilingControlsMinScreenWidthForText,
            onPressed: !profilerBusy
                ? () {
                    ga.select(
                      analytics_constants.cpuProfiler,
                      analytics_constants.profileAppStartUp,
                    );
                    controller.cpuProfilerController.loadAppStartUpProfile();
                  }
                : null,
          ),
        const SizedBox(width: denseSpacing),
        RefreshButton(
          label: 'Load all CPU samples',
          tooltip: 'Load all available CPU samples from the profiler',
          minScreenWidthForTextBeforeScaling:
              _profilingControlsMinScreenWidthForText,
          onPressed: !profilerBusy
              ? () {
                  ga.select(
                    analytics_constants.cpuProfiler,
                    analytics_constants.loadAllCpuSamples,
                  );
                  controller.cpuProfilerController.loadAllSamples();
                }
              : null,
        ),
        const SizedBox(width: denseSpacing),
        ProfileGranularityDropdown(
          screenId: ProfilerScreen.id,
          profileGranularityFlagNotifier:
              controller.cpuProfilerController.profileGranularityFlagNotifier!,
        ),
        const SizedBox(width: denseSpacing),
        ExportButton(
          onPressed: !profilerBusy &&
                  controller.cpuProfileData != null &&
                  controller.cpuProfileData?.isEmpty == false
              ? () {
                  ga.select(
                    analytics_constants.cpuProfiler,
                    analytics_constants.export,
                  );
                  _exportPerformance(context);
                }
              : null,
          minScreenWidthForTextBeforeScaling:
              _secondaryControlsMinScreenWidthForText,
        ),
      ],
    );
  }

  void _exportPerformance(BuildContext context) {
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    // TODO(peterdjlee): find a way to push the notification logic into the
    // export controller.
    notificationService.push(successfulExportMessage(exportedFile));
  }
}

class ProfilerScreenMetrics extends ScreenAnalyticsMetrics {
  ProfilerScreenMetrics({
    required this.cpuSampleCount,
    required this.cpuStackDepth,
  });

  final int cpuSampleCount;
  final int cpuStackDepth;
}
