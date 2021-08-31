// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../globals.dart';
import '../ui/filter.dart';
import '../ui/search.dart';
import '../utils.dart';
import '../vm_flags.dart' as vm_flags;
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profile_transformer.dart';
import 'profiler_screen.dart';

class CpuProfilerController
    with
        SearchControllerMixin<CpuStackFrame>,
        FilterControllerMixin<CpuStackFrame> {
  CpuProfilerController({this.analyticsScreenId});

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

  /// The analytics screen id for which this controller is active.
  final String analyticsScreenId;

  /// Store of cached CPU profiles.
  final cpuProfileStore = CpuProfileStore();

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

  @visibleForTesting
  final dataByTag = <String, CpuProfileData>{};

  Iterable<String> get userTags => dataByTag[userTagNone]?.userTags ?? [];

  /// The toggle filters available for the CPU profiler.
  ///
  /// This is a getter so that `serviceManager` is initialized by the time we
  /// access this list.
  // TODO(kenz): make this late once we migrate to null safety.
  List<ToggleFilter<CpuStackFrame>> get toggleFilters => _toggleFilters ??= [
        ToggleFilter<CpuStackFrame>(
          name: 'Hide Native code',
          includeCallback: (stackFrame) => !stackFrame.isNative,
          enabledByDefault: true,
        ),
        ToggleFilter<CpuStackFrame>(
          name: 'Hide core Dart libraries',
          includeCallback: (stackFrame) => !stackFrame.isDartCore,
        ),
        if (serviceManager.connectedApp?.isFlutterAppNow ?? true)
          ToggleFilter<CpuStackFrame>(
            name: 'Hide core Flutter libraries',
            includeCallback: (stackFrame) => !stackFrame.isFlutterCore,
          ),
      ];

  List<ToggleFilter<CpuStackFrame>> _toggleFilters;

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
      offlineMode ? true : profilerFlagNotifier.value.valueAsString == 'true';

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

    Future<void> pullAndProcessHelper() async {
      // TODO(kenz): add a cancel button to the processing UI in case pulling a
      // large payload from the vm service takes a long time.
      cpuProfileData = await serviceManager.service.getCpuProfile(
        startMicros: startMicros,
        extentMicros: extentMicros,
      );
      await processAndSetData(
        cpuProfileData,
        processId: processId,
        storeAsUserTagNone: true,
        shouldApplyFilters: true,
      );
      cpuProfileStore.addProfile(
        TimeRange()
          ..start = Duration(microseconds: startMicros)
          ..end = Duration(microseconds: startMicros + extentMicros),
        _dataNotifier.value,
      );
    }

    if (analyticsScreenId != null) {
      // Pull and process cpu profile data [pullAndProcessHelper] and time the
      // operation for analytics.
      await ga.timeAsync(
        analyticsScreenId,
        analytics_constants.cpuProfileProcessingTime,
        asyncOperation: pullAndProcessHelper,
        screenMetricsProvider: () => ProfilerScreenMetrics(
          cpuSampleCount: cpuProfileData.profileMetaData.sampleCount,
          cpuStackDepth: cpuProfileData.profileMetaData.stackDepth,
        ),
      );
    } else {
      try {
        await pullAndProcessHelper();
      } on ProcessCancelledException catch (_) {
        // Do nothing because the attempt to process data has been cancelled in
        // favor of a new one.
      }
    }
  }

  /// Processes [cpuProfileData] and sets the data for the controller.
  ///
  /// If `storeAsUserTagNone` is true, the processed data will be stored as the
  /// original data, where no user tag filter has been applied.
  Future<void> processAndSetData(
    CpuProfileData cpuProfileData, {
    @required String processId,
    @required bool storeAsUserTagNone,
    @required bool shouldApplyFilters,
  }) async {
    _processingNotifier.value = true;
    _dataNotifier.value = null;
    try {
      await transformer.processData(cpuProfileData, processId: processId);
      if (storeAsUserTagNone) {
        dataByTag[userTagNone] = cpuProfileData;
      }
      if (shouldApplyFilters) {
        cpuProfileData = _filterData(
          cpuProfileData,
          Filter(toggleFilters: toggleFilters),
        );
        await transformer.processData(cpuProfileData, processId: processId);
      }
      _dataNotifier.value = cpuProfileData;
      refreshSearchMatches();
      _processingNotifier.value = false;
    } on AssertionError catch (_) {
      _dataNotifier.value = cpuProfileData;
      _processingNotifier.value = false;
      // Rethrow after setting notifiers so that cpu profile data is included
      // in the timeline export.
      rethrow;
    }
  }

  @override
  List<CpuStackFrame> matchesForSearch(String search) {
    if (search?.isEmpty ?? true) return [];
    final regexSearch = RegExp(search, caseSensitive: false);
    final matches = <CpuStackFrame>[];
    final currentStackFrames = _dataNotifier.value.stackFrames.values;
    for (final frame in currentStackFrames) {
      if (frame.name.caseInsensitiveContains(regexSearch) ||
          frame.processedUrl.caseInsensitiveContains(regexSearch)) {
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
    dataByTag[userTagNone] = data;
  }

  Future<void> loadDataWithTag(String tag) async {
    _userTagFilter.value = tag;

    _dataNotifier.value = null;
    _processingNotifier.value = true;

    try {
      _dataNotifier.value = await processDataForTag(tag);
    } catch (e) {
      // In the event of an error, reset the data to the original CPU profile.
      _dataNotifier.value = dataByTag[userTagNone];
      throw Exception('Error loading data with tag "$tag": ${e.toString()}');
    } finally {
      _processingNotifier.value = false;
    }
  }

  Future<CpuProfileData> processDataForTag(String tag) async {
    final fullData = dataByTag[userTagNone];
    final data = dataByTag.putIfAbsent(
      tag,
      () => CpuProfileData.fromUserTag(fullData, tag),
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
    cpuProfileStore.clear();
    await serviceManager.service.clearSamples();
  }

  void reset() {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = baseStateCpuProfileData;
    dataByTag.clear();
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

  /// Tracks the identifier for the attempt to filter the data.
  ///
  /// We use this to prevent multiple filter calls from processing data at the
  /// same time.
  int _filterIdentifier = 0;

  @override
  void filterData(Filter<CpuStackFrame> filter) {
    final originalData = dataByTag[userTagNone];
    final filteredData = _filterData(originalData, filter);
    processAndSetData(
      filteredData,
      processId: 'filter $_filterIdentifier',
      storeAsUserTagNone: false,
      shouldApplyFilters: false,
    );
    _filterIdentifier++;
  }

  CpuProfileData _filterData(
    CpuProfileData originalData,
    Filter<CpuStackFrame> filter,
  ) {
    final filterCallback = (CpuStackFrame stackFrame) {
      var shouldInclude = true;
      for (final toggleFilter in filter.toggleFilters) {
        if (toggleFilter.enabled.value) {
          shouldInclude =
              shouldInclude && toggleFilter.includeCallback(stackFrame);
          if (!shouldInclude) return false;
        }
      }
      return shouldInclude;
    };
    return CpuProfileData.filterFrom(originalData, filterCallback);
  }
}
