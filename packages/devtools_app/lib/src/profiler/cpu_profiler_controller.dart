// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../ui/fake_flutter/fake_flutter.dart';

class CpuProfilerController {
  CpuProfilerController() {
    dummyEmptyCpuProfileData = CpuProfileData.parse({});
    _dataNotifier = ValueNotifier<CpuProfileData>(dummyEmptyCpuProfileData);
  }

  /// Notifies that new cpu profile data is available.
  ValueListenable get dataNotifier => _dataNotifier;
  ValueNotifier<CpuProfileData> _dataNotifier;

  /// Notifies that a cpu stack frame was selected.
  ValueListenable get selectedCpuStackFrameNotifier =>
      _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame>(null);

  final CpuProfilerService service = CpuProfilerService();

  final CpuProfileTransformer transformer = CpuProfileTransformer();

  /// Dummy data for the initial value of [_dataNotifier].
  ///
  /// This dummy data will also be set upon clearing the controller.
  CpuProfileData dummyEmptyCpuProfileData;

  Future<void> pullAndProcessProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    final cpuProfileData = await service.getCpuProfile(
      startMicros: startMicros,
      extentMicros: extentMicros,
    );
    transformer.processData(cpuProfileData);
    _dataNotifier.value = cpuProfileData;
  }

  void selectCpuStackFrame(CpuStackFrame stackFrame) {
    if (stackFrame == dataNotifier.value.selectedStackFrame) return;
    dataNotifier.value.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    resetNotifiers();
    await service.clearCpuSamples();
  }

  void resetNotifiers({bool useDummyData = true}) {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = useDummyData ? dummyEmptyCpuProfileData : null;
  }
}
