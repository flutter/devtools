// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/file_import.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/screen.dart';
import '../../shared/utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profiler.dart';
import 'cpu_profiler_controller.dart';
import 'panes/controls/profiler_screen_controls.dart';
import 'profiler_screen_controller.dart';
import 'profiler_status.dart';

class ProfilerScreen extends Screen {
  ProfilerScreen() : super.fromMetaData(ScreenMetaData.cpuProfiler);

  static final id = ScreenMetaData.cpuProfiler.id;

  @override
  String get docPageId => id;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) {
    final connected = serviceConnection.serviceManager.hasConnection &&
        serviceConnection.serviceManager.connectedAppInitialized;
    if (!connected && !offlineController.offlineMode.value) {
      return const DisconnectedCpuProfilerScreenBody();
    }

    return const ProfilerScreenBody();
  }
}

class ProfilerScreenBody extends StatefulWidget {
  const ProfilerScreenBody({super.key});

  @override
  State<ProfilerScreenBody> createState() => _ProfilerScreenBodyState();
}

class _ProfilerScreenBodyState extends State<ProfilerScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<ProfilerScreenController, ProfilerScreenBody> {
  bool recording = false;

  late CpuProfilerBusyStatus profilerBusyStatus;

  bool get profilerBusy => profilerBusyStatus != CpuProfilerBusyStatus.none;

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

    recording = controller.recordingNotifier.value;
    addAutoDisposeListener(controller.recordingNotifier, () {
      setState(() {
        recording = controller.recordingNotifier.value;
      });
    });

    profilerBusyStatus =
        controller.cpuProfilerController.profilerBusyStatus.value;
    addAutoDisposeListener(
      controller.cpuProfilerController.profilerBusyStatus,
      () {
        setState(() {
          profilerBusyStatus =
              controller.cpuProfilerController.profilerBusyStatus.value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (offlineController.offlineMode.value) {
      return _buildProfilerScreenBody(controller);
    }
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
        final status = recording || profilerBusy
            ? (recording
                ? const RecordingStatus()
                : ProfilerBusyStatus(status: profilerBusyStatus))
            : null;
        return Column(
          children: [
            ProfilerScreenControls(
              controller: controller,
              recording: recording,
              processing: profilerBusy,
              offline: offlineController.offlineMode.value,
            ),
            const SizedBox(height: intermediateSpacing),
            Expanded(
              child: status ??
                  ValueListenableBuilder<CpuProfileData?>(
                    valueListenable:
                        controller.cpuProfilerController.dataNotifier,
                    builder: (context, cpuProfileData, _) {
                      if (cpuProfileData == null ||
                          cpuProfileData ==
                              CpuProfilerController.baseStateCpuProfileData) {
                        return const ProfileRecordingInstructions();
                      }
                      if (cpuProfileData ==
                          CpuProfilerController.emptyAppStartUpProfile) {
                        return const EmptyAppStartUpProfile();
                      }
                      if (cpuProfileData.isEmpty &&
                          !controller.cpuProfilerController.isFilterActive) {
                        return const EmptyProfileView();
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
}

class DisconnectedCpuProfilerScreenBody extends StatelessWidget {
  const DisconnectedCpuProfilerScreenBody({super.key});

  static const importInstructions =
      'Open a CPU profile that was previously saved from DevTools';

  @override
  Widget build(BuildContext context) {
    return FileImportContainer(
      instructions: importInstructions,
      actionText: 'Load data',
      gaScreen: gac.appSize,
      gaSelectionImport: gac.CpuProfilerEvents.openDataFile.name,
      gaSelectionAction: gac.CpuProfilerEvents.loadDataFromFile.name,
      onAction: (jsonFile) {
        Provider.of<ImportController>(context, listen: false)
            .importData(jsonFile, expectedScreenId: ProfilerScreen.id);
      },
    );
  }
}
