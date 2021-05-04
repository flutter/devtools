// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/import_export/import_export.dart';
import '../globals.dart';
import '../notifications.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/icons.dart';
import '../ui/vm_flag_widgets.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler.dart';
import 'profiler_screen_controller.dart';

final profilerScreenSearchFieldKey =
    GlobalKey(debugLabel: 'ProfilerScreenSearchFieldKey');

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
        OfflineScreenMixin<ProfilerScreenBody, CpuProfileData> {
  ProfilerScreenController controller;

  bool recording = false;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    ga.screen(ProfilerScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, ProfilerScreen.id);

    final newController = Provider.of<ProfilerScreenController>(context);
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

    // Load offline profiler data if available.
    if (shouldLoadOfflineData()) {
      final profilerJson =
          Map<String, dynamic>.from(offlineDataJson[ProfilerScreen.id]);
      final offlineProfilerData = CpuProfileData.parse(profilerJson);
      if (!offlineProfilerData.isEmpty) {
        loadOfflineData(offlineProfilerData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (offlineMode) return _buildProfilerScreenBody(controller);
    return ValueListenableBuilder<Flag>(
      valueListenable: controller.cpuProfilerController.profilerFlagNotifier,
      builder: (context, profilerFlag, _) {
        return profilerFlag.valueAsString == 'true'
            ? _buildProfilerScreenBody(controller)
            : CpuProfilerDisabled(controller.cpuProfilerController);
      },
    );
  }

  Widget _buildProfilerScreenBody(ProfilerScreenController controller) {
    final profilerScreen = Column(
      children: [
        if (!offlineMode)
          ProfilerScreenControls(
            controller: controller,
            recording: recording,
          ),
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
    await controller.cpuProfilerController.transformer.processData(offlineData);
    controller.cpuProfilerController.loadData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[ProfilerScreen.id] != null;
  }
}

class ProfilerScreenControls extends StatelessWidget {
  const ProfilerScreenControls({
    @required this.controller,
    @required this.recording,
  });

  final ProfilerScreenController controller;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PrimaryControls(
          controller: controller,
          recording: recording,
        ),
        _SecondaryControls(
          controller: controller,
        ),
      ],
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    @required this.controller,
    @required this.recording,
  });

  static const _primaryControlsMinIncludeTextWidth = 600.0;

  final ProfilerScreenController controller;

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordButton(
          recording: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: controller.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        StopRecordingButton(
          recording: recording,
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: controller.stopRecording,
        ),
        const SizedBox(width: defaultSpacing),
        ClearButton(
          includeTextWidth: _primaryControlsMinIncludeTextWidth,
          onPressed: recording ? null : controller.clear,
        ),
      ],
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({@required this.controller});

  static const _secondaryControlsMinIncludeTextWidth = 1100.0;

  final ProfilerScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ProfileGranularityDropdown(ProfilerScreen.id),
        const SizedBox(width: defaultSpacing),
        ExportButton(
          onPressed: controller.cpuProfileData != null &&
                  !controller.cpuProfileData.isEmpty
              ? () => _exportPerformance(context)
              : null,
          includeTextWidth: _secondaryControlsMinIncludeTextWidth,
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
    Notifications.of(context).push(successfulExportMessage(exportedFile));
  }
}
