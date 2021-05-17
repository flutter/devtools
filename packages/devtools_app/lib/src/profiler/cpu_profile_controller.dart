// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../ui/search.dart';
import '../utils.dart';
import '../vm_flags.dart' as vm_flags;
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profile_transformer.dart';

class CpuProfilerController with SearchControllerMixin<CpuStackFrame> {
  /// Tag to represent when no user tag filters are applied.
  ///
  /// The word 'none' is not a magic word - just a user-friendly name to convey
  /// the message that no filters are applied.
  static const userTagNone = 'none';

  /// Data for the initial value and reset value of [_dataNotifier].
  ///
  /// When this data is the value of [_dataNotifier], the CPU profiler is in a
  /// base state where recording instructions should be shown.
  static CpuProfileData baseStateCpuProfileData = CpuProfileData.empty();

  /// Notifies that new cpu profile data is available.
  ValueListenable<CpuProfileData> get dataNotifier => _dataNotifier;
  final _dataNotifier = ValueNotifier<CpuProfileData>(baseStateCpuProfileData);

  /// Notifies that CPU profile data is currently being processed.
  ValueListenable get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  /// Notifies that a cpu stack frame was selected.
  ValueListenable get selectedCpuStackFrameNotifier =>
      _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame>(null);

  /// Notifies that a user tag filter is set on the CPU profile flame chart.
  ValueListenable<String> get userTagFilter => _userTagFilter;
  final _userTagFilter = ValueNotifier<String>(userTagNone);

  final _dataByTag = <String, CpuProfileData>{};

  Iterable<String> get userTags => _dataByTag[userTagNone]?.userTags ?? [];

  int selectedProfilerTabIndex = 0;

  void changeSelectedProfilerTab(int index) {
    selectedProfilerTabIndex = index;
  }

  final transformer = CpuProfileTransformer();

  /// Notifies that the vm profiler flag has changed.
  ValueNotifier<Flag> get profilerFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profiler);

  ValueNotifier<Flag> get profileGranularityFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profilePeriod);

  /// Whether the profiler is enabled.
  ///
  /// Clients interested in the current value of [profilerFlagNotifier] should
  /// use this getter. Otherwise, clients subscribing to change notifications,
  /// should listen to [profilerFlagNotifier].
  bool get profilerEnabled =>
      profilerFlagNotifier.value.valueAsString == 'true';

  Future<dynamic> enableCpuProfiler() {
    return serviceManager.service.enableCpuProfiler();
  }

  Future<void> pullAndProcessProfile({
    @required int startMicros,
    @required int extentMicros,
    String processId,
  }) async {
    if (!profilerEnabled) return;
    assert(_dataNotifier.value != null);
    assert(!_processingNotifier.value);

    _processingNotifier.value = true;

    var cpuProfileData = baseStateCpuProfileData;

    _dataNotifier.value = null;
    // TODO(kenz): add a cancel button to the processing UI in case pulling a
    // large payload from the vm service takes a long time.
    cpuProfileData = await serviceManager.service.getCpuProfile(
      startMicros: startMicros,
      extentMicros: extentMicros,
    );

    try {
      await transformer.processData(cpuProfileData, processId: processId);
      _dataNotifier.value = cpuProfileData;
      _dataByTag[userTagNone] = cpuProfileData;
      refreshSearchMatches();
      _processingNotifier.value = false;
    } on AssertionError catch (_) {
      _dataNotifier.value = cpuProfileData;
      _processingNotifier.value = false;
      // Rethrow after setting notifiers so that cpu profile data is included
      // in the timeline export.
      rethrow;
    } on ProcessCancelledException catch (_) {
      // Do nothing because the attempt to process data has been cancelled in
      // favor of a new one.
    }
  }

  @override
  List<CpuStackFrame> matchesForSearch(String search) {
    if (search?.isEmpty ?? true) return [];
    final matches = <CpuStackFrame>[];
    final currentStackFrames = _dataNotifier.value.stackFrames.values;
    for (final frame in currentStackFrames) {
      if (frame.name.caseInsensitiveContains(search) ||
          frame.url.caseInsensitiveContains(search)) {
        matches.add(frame);
        frame.isSearchMatch = true;
      } else {
        frame.isSearchMatch = false;
      }
    }
    return matches;
  }

  void loadProcessedData(CpuProfileData data) {
    assert(data.processed);
    _dataNotifier.value = data;
    _dataByTag[userTagNone] = data;
  }

  Future<void> loadDataWithTag(String tag) async {
    _userTagFilter.value = tag;

    _dataNotifier.value = null;
    _processingNotifier.value = true;

    try {
      _dataNotifier.value = await processDataForTag(tag);
    } catch (e) {
      // In the event of an error, reset the data to the original CPU profile.
      _dataNotifier.value = _dataByTag[userTagNone];
      throw Exception('Error loading data with tag "$tag": ${e.toString()}');
    } finally {
      _processingNotifier.value = false;
    }
  }

  Future<CpuProfileData> processDataForTag(String tag) async {
    final fullData = _dataByTag[userTagNone];
    final data = _dataByTag.putIfAbsent(
      tag,
      () => fullData.dataForUserTag(tag),
    );
    if (!data.processed) {
      await transformer.processData(data);
    }
    return data;
  }

  void selectCpuStackFrame(CpuStackFrame stackFrame) {
    if (stackFrame == dataNotifier.value.selectedStackFrame) return;
    dataNotifier.value.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    reset();
    await serviceManager.service.clearSamples();
  }

  void reset() {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = baseStateCpuProfileData;
    _dataByTag.clear();
    _processingNotifier.value = false;
    transformer.reset();
    resetSearch();
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
