// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/config_specific/logger/allowed_error.dart';
import '../../shared/globals.dart';
import '../../shared/offline_mode.dart';
import '../../shared/primitives/utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profiler_controller.dart';
import 'profiler_screen.dart';
import 'sampling_rate.dart';

class ProfilerScreenController extends DisposableController
    with
        AutoDisposeControllerMixin,
        OfflineScreenControllerMixin<CpuProfileData> {
  ProfilerScreenController() {
    unawaited(_init());
  }

  final _initialized = Completer<void>();

  Future<void> get initialized => _initialized.future;

  Future<void> _init() async {
    await _initHelper();
    _initialized.complete();
  }

  Future<void> _initHelper() async {
    initReviewHistoryOnDisconnectListener();
    if (!offlineDataController.showingOfflineData.value) {
      await allowedError(
        serviceConnection.serviceManager.service!
            .setProfilePeriod(mediumProfilePeriod),
        logError: false,
      );

      _currentIsolate =
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
      addAutoDisposeListener(
        serviceConnection.serviceManager.isolateManager.selectedIsolate,
        () {
          final selectedIsolate = serviceConnection
              .serviceManager.isolateManager.selectedIsolate.value;
          if (selectedIsolate != null) {
            switchToIsolate(selectedIsolate);
          }
        },
      );

      addAutoDisposeListener(preferences.vmDeveloperModeEnabled, () async {
        if (preferences.vmDeveloperModeEnabled.value) {
          // If VM developer mode was just enabled, clear the profile store
          // since the existing entries won't have code profiles and cannot be
          // constructed from function profiles.
          cpuProfilerController.cpuProfileStore.clear();
          cpuProfilerController.reset();
        } else {
          // If VM developer mode is disabled and we're grouping by VM tags, we
          // need to default to the basic view of the profile.
          final userTagFilter = cpuProfilerController.userTagFilter.value;
          if (userTagFilter == CpuProfilerController.groupByVmTag) {
            await cpuProfilerController
                .loadDataWithTag(CpuProfilerController.userTagNone);
          }
        }
        // Always reset to the function view when the VM developer mode state
        // changes. The selector is hidden when VM developer mode is disabled
        // and data for code profiles won't be requested.
        cpuProfilerController.updateViewForType(CpuProfilerViewType.function);
      });
    } else {
      await maybeLoadOfflineData(
        ProfilerScreen.id,
        createData: (json) => CpuProfileData.parse(json),
        shouldLoad: (data) => !data.isEmpty,
      );
    }
  }

  final cpuProfilerController = CpuProfilerController();

  CpuProfileData? get cpuProfileData =>
      cpuProfilerController.dataNotifier.value;

  final _previousProfileByIsolateId = <String?, CpuProfileData?>{};

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable<bool> get recordingNotifier => _recordingNotifier;

  final _recordingNotifier = ValueNotifier<bool>(false);

  IsolateRef? _currentIsolate;

  void switchToIsolate(IsolateRef? ref) {
    // Store the data for the current isolate.
    if (_currentIsolate?.id != null) {
      _previousProfileByIsolateId[_currentIsolate?.id] =
          cpuProfilerController.dataNotifier.value;
    }
    // Update the current isolate.
    _currentIsolate = ref;
    // Load any existing data for the new isolate.
    final previousData = _previousProfileByIsolateId[ref?.id];
    _recordingNotifier.value = false;
    cpuProfilerController.reset(data: previousData);
  }

  int _profileRequestId = 0;

  Future<void> startRecording() async {
    await clear();
    _recordingNotifier.value = true;
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;
    await cpuProfilerController.pullAndProcessProfile(
      // We start at 0 every time because [startRecording] clears the cpu
      // samples on the VM.
      startMicros: 0,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
      processId: 'Profile ${++_profileRequestId}',
    );
  }

  @override
  OfflineScreenData screenDataForExport() => OfflineScreenData(
        screenId: ProfilerScreen.id,
        data: cpuProfileData!.toJson,
      );

  @override
  FutureOr<void> processOfflineData(CpuProfileData offlineData) async {
    await cpuProfilerController.transformer.processData(
      offlineData,
      processId: 'offline data processing',
    );
    cpuProfilerController.loadProcessedData(
      CpuProfilePair(
        functionProfile: offlineData,
        codeProfile: null,
      ),
      storeAsUserTagNone: true,
    );
  }

  Future<void> clear() async {
    await cpuProfilerController.clear();
  }

  @override
  void dispose() {
    _recordingNotifier.dispose();
    cpuProfilerController.dispose();
    super.dispose();
  }
}
