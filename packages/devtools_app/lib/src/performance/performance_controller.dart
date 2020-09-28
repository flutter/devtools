// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../config_specific/import_export/import_export.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_model.dart';
import '../utils.dart';
import 'performance_screen.dart';

class PerformanceController with CpuProfilerControllerProviderMixin {
  final _exportController = ExportController();

  CpuProfileData get cpuProfileData => cpuProfilerController.dataNotifier.value;

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable get recordingNotifier => _recordingNotifier;
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
    );
  }

  /// Exports the current performance data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData =
        _exportController.encode(PerformanceScreen.id, cpuProfileData.json);
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
