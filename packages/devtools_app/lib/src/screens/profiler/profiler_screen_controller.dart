// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/config_specific/logger/allowed_error.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profiler_controller.dart';
import 'profiler_screen.dart';
import 'sampling_rate.dart';

class ProfilerScreenController extends DisposableController
    with AutoDisposeControllerMixin {
  ProfilerScreenController() {
    if (!offlineController.offlineMode.value) {
      unawaited(
        allowedError(
          serviceManager.service!.setProfilePeriod(mediumProfilePeriod),
          logError: false,
        ),
      );

      _currentIsolate = serviceManager.isolateManager.selectedIsolate.value;
      addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
        switchToIsolate(serviceManager.isolateManager.selectedIsolate.value);
      });

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
    }
  }

  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: gac.cpuProfiler);

  final _exportController = ExportController();

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

  /// Exports the current profiler data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(ProfilerScreen.id, cpuProfileData!.toJson);
    return _exportController.downloadFile(encodedData);
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
