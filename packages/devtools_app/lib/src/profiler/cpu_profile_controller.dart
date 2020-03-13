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
  ValueListenable get data => _dataNotifier;
  final _dataNotifier = ValueNotifier<CpuProfileData>(baseStateCpuProfileData);

  /// Notifies that CPU profile data is currently being processed.
  ValueListenable get processing => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  /// Notifies that a cpu stack frame was selected.
  ValueListenable get selectedCpuStackFrame => _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame>(null);

  final service = CpuProfilerService();

  final transformer = CpuProfileTransformer();

  /// Notifies that the vm profiler flag has changed.
  ValueListenable get profilerFlag => service.profilerFlagNotifier;

  /// Whether the profiler is enabled.
  ///
  /// Clients interested in the current value of [profilerFlag] should
  /// use this getter. Otherwise, clients subscribing to change notifications,
  /// should listen to [profilerFlag].
  bool get profilerEnabled => profilerFlag.value.valueAsString == 'true';

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
    if (stackFrame == data.value.selectedStackFrame) return;
    data.value.selectedStackFrame = stackFrame;
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

final Map<String, dynamic> cpuProfileResponseJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'stackDepth': 128,
  'sampleCount': 7,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377800463,
  'timeExtentMicros': 600,
  'stackFrames': goldenCpuProfileStackFrames,
  'traceEvents': goldenCpuProfileTraceEvents,
};

final Map<String, dynamic> goldenCpuProfileStackFrames = {
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'A',
    'resolvedUrl': 'B',
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': 'A1',
    'parent': '140357727781376-1',
    'resolvedUrl': 'B',
  },
  '140357727781376-3': {
    'category': 'Dart',
    'name': 'A2',
    'parent': '140357727781376-1',
    'resolvedUrl': 'A',
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': 'A2-A child',
    'parent': '140357727781376-3',
    'resolvedUrl': 'B',
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'A2-B child',
    'parent': '140357727781376-3',
    'resolvedUrl': 'A',
  },
  '140357727781376-6': {
    'category': 'Dart',
    'name': 'A2-C child',
    'parent': '140357727781376-3',
    'resolvedUrl': 'C',
  },
  '140357727781376-7': {
    'category': 'Dart',
    'name': 'B',
    'resolvedUrl': 'A',
  },
  '140357727781376-8': {
    'category': 'Dart',
    'name': 'B1',
    'parent': '140357727781376-7',
    'resolvedUrl': 'B',
  },
  '140357727781376-9': {
    'category': 'Dart',
    'name': 'B2',
    'parent': '140357727781376-7',
    'resolvedUrl': 'A',
  },
};

final List<Map<String, dynamic>> goldenCpuProfileTraceEvents = [
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800463,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-2'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800563,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-2'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800663,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-4'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800763,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-5'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800863,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-6'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800963,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-8'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377801063,
    'cat': 'Dart',
    'args': {'mode': 'basic'},
    'sf': '140357727781376-9'
  },
];
