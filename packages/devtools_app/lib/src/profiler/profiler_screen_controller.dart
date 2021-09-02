// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../config_specific/import_export/import_export.dart';
import '../utils.dart';
import 'cpu_profile_controller.dart';
import 'cpu_profile_model.dart';
import 'profiler_screen.dart';

class ProfilerScreenController {
  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: analytics_constants.cpuProfiler);

  final _exportController = ExportController();

  CpuProfileData get cpuProfileData => cpuProfilerController.dataNotifier.value;

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable<bool> get recordingNotifier => _recordingNotifier;

  final _recordingNotifier = ValueNotifier<bool>(false);

  final int _profileStartMicros = 0;

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

  Future<void> loadAllSamples() async {
    cpuProfilerController.reset();
    await cpuProfilerController.pullAndProcessProfile(
      startMicros: 0,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
      processId: 'Load all samples',
    );
  }

  /// Exports the current profiler data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(ProfilerScreen.id, cpuProfileData.toJson);
    return _exportController.downloadFile(encodedData);
  }

  Future<void> clear() async {
    await cpuProfilerController.clear();
  }

  void dispose() {
    _recordingNotifier.dispose();
    cpuProfilerController.dispose();
  }
}
