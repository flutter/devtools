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

  /// Notifies that CPU profile data is currently being processed.
  ValueListenable get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  /// Notifies that a cpu stack frame was selected.
  ValueListenable get selectedCpuStackFrameNotifier =>
      _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame>(null);

  final service = CpuProfilerService();

  final transformer = CpuProfileTransformer();

  /// Notifies that the vm profiler flag has changed.
  ValueListenable get profilerFlagNotifier => service.profilerFlagNotifier;

  /// Whether the profiler is enabled.
  ///
  /// Clients interested in the current value of [profilerFlagNotifier] should
  /// use this getter. Otherwise, clients subscribing to change notifications,
  /// should listen to [profilerFlagNotifier].
  bool get profilerEnabled =>
      profilerFlagNotifier.value.valueAsString == 'true';

  Future<dynamic> enableCpuProfiler() {
    return service.enableCpuProfiler();
  }

  Future<void> pullAndProcessProfile({
    @required int startMicros,
    @required int extentMicros,
  }) async {
    if (!profilerEnabled) return;
    assert(_dataNotifier.value != null);
    assert(!_processingNotifier.value);

    _processingNotifier.value = true;

    var cpuProfileData = baseStateCpuProfileData;

    _dataNotifier.value = null;
    // TODO(kenz): add a cancel button to the processing UI in case pulling a
    // large payload from the vm service takes a long time.
    cpuProfileData = await service.getCpuProfile(
      startMicros: startMicros,
      extentMicros: extentMicros,
    );

    try {
      await transformer.processData(cpuProfileData);
      _dataNotifier.value = cpuProfileData;
      _processingNotifier.value = false;
    } on AssertionError catch (_) {
      _dataNotifier.value = cpuProfileData;
      _processingNotifier.value = false;
      // Rethrow after setting notifiers so that cpu profile data is included
      // in the timeline export.
      rethrow;
    }
  }

  void loadOfflineData(CpuProfileData data) {
    _dataNotifier.value = data;
  }

  void selectCpuStackFrame(CpuStackFrame stackFrame) {
    if (stackFrame == dataNotifier.value.selectedStackFrame) return;
    dataNotifier.value.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    reset();
    await service.clearCpuSamples();
  }

  void reset() {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = baseStateCpuProfileData;
    _processingNotifier.value = false;
    transformer.reset();
  }

  void dispose() {
    _dataNotifier.dispose();
    _selectedCpuStackFrameNotifier.dispose();
    _processingNotifier.dispose();
    transformer.dispose();
  }
}

mixin CpuProfilerControllerProviderMixin {
  final cpuProfilerController = CpuProfilerController();
}
