// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../ui/fake_flutter/fake_flutter.dart';

class CpuProfilerController {
  /// Data for the initial value and reset value of [_dataNotifier].
  ///
  /// When this data is the value of [_dataNotifier], the CPU profiler is in a
  /// base state where recording instructions should be shown.
  static CpuProfileData baseStateCpuProfileData = CpuProfileData.empty();

  /// Notifies that new cpu profile data is available.
  ValueListenable get dataNotifier => _dataNotifier;
  final _dataNotifier = ValueNotifier<CpuProfileData>(baseStateCpuProfileData);

  /// Notifies that a cpu stack frame was selected.
  ValueListenable get selectedCpuStackFrameNotifier =>
      _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame>(null);

  final service = CpuProfilerService();

  final transformer = CpuProfileTransformer();

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

  void resetNotifiers({bool useBaseStateData = true}) {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = useBaseStateData ? baseStateCpuProfileData : null;
  }
}
