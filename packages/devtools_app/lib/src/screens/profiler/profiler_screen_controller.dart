// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/import_export/import_export.dart';
import '../../config_specific/logger/allowed_error.dart';
import '../../primitives/auto_dispose.dart';
import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'profile_granularity.dart';
import 'profiler_screen.dart';

class ProfilerScreenController extends DisposableController
    with AutoDisposeControllerMixin {
  ProfilerScreenController() {
    if (!offlineController.offlineMode.value) {
      allowedError(
        serviceManager.service!.setProfilePeriod(mediumProfilePeriod),
        logError: false,
      );

      _currentIsolate = serviceManager.isolateManager.selectedIsolate.value;
      addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
        switchToIsolate(serviceManager.isolateManager.selectedIsolate.value);
      });
    }
  }

  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: analytics_constants.cpuProfiler);

  final _exportController = ExportController();

  CpuProfileData? get cpuProfileData =>
      cpuProfilerController.dataNotifier.value;

  final _previousProfileByIsolateId = <String?, CpuProfileData?>{};

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable<bool> get recordingNotifier => _recordingNotifier;

  final _recordingNotifier = ValueNotifier<bool>(false);

  final int _profileStartMicros = 0;

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

  Future<void> startRecording() async {
    await clear();
    _recordingNotifier.value = true;
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;
    await cpuProfilerController.pullAndProcessProfile(
      startMicros: _profileStartMicros,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
      processId: 'Profile $_profileStartMicros',
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
