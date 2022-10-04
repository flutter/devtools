// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../primitives/utils.dart';
import '../../service/vm_flags.dart' as vm_flags;
import '../../shared/globals.dart';
import '../../ui/filter.dart';
import '../../ui/search.dart';
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

  /// User tag that marks app start up for Flutter apps.
  ///
  /// This needs to match the tag set and unset at these locations,
  /// respectively:
  ///
  /// Flutter Engine - https://github.com/flutter/engine/blob/f52653ba4568b4a40e8624d47773d156740ea9f7/runtime/dart_isolate.cc#L369
  /// Flutter Framework - https://github.com/flutter/flutter/blob/33f4107cd1029c3847f119e23719f6147dbc39db/packages/flutter/lib/src/widgets/binding.dart#L866
  static const appStartUpUserTag = 'AppStartUp';

  /// Data for the initial value and reset value of [_dataNotifier].
  ///
  /// When this data is the value of [_dataNotifier], the CPU profiler is in a
  /// base state where recording instructions should be shown.
  static CpuProfileData baseStateCpuProfileData = CpuProfileData.empty();

  /// Data used to represent and empty profile when attempting to load the
  /// 'AppStartUp' profile.
  ///
  /// When this data is the value of [_dataNotifier], the CPU profiler will show
  /// an empty message specific to the app start up use case.
  static CpuProfileData emptyAppStartUpProfile = CpuProfileData.empty();

  /// The analytics screen id for which this controller is active.
  final String? analyticsScreenId;

  /// The store of cached CPU profiles for the currently selected isolate.
  CpuProfileStore get cpuProfileStore =>
      _cpuProfileStoreByIsolateId.putIfAbsent(
        serviceManager.isolateManager.selectedIsolate.value?.id ?? '',
        () => CpuProfileStore(),
      );

  /// Store of cached CPU profiles for each isolate.
  final _cpuProfileStoreByIsolateId = <String, CpuProfileStore>{};

  /// Notifies that new cpu profile data is available.
  ValueListenable<CpuProfileData?> get dataNotifier => _dataNotifier;
  final _dataNotifier = ValueNotifier<CpuProfileData?>(baseStateCpuProfileData);

  /// Notifies that CPU profile data is currently being processed.
  ValueListenable get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  /// Notifies that a cpu stack frame was selected.
  ValueListenable<CpuStackFrame?> get selectedCpuStackFrameNotifier =>
      _selectedCpuStackFrameNotifier;
  final _selectedCpuStackFrameNotifier = ValueNotifier<CpuStackFrame?>(null);

  /// Notifies that a user tag filter is set on the CPU profile flame chart.
  ValueListenable<String> get userTagFilter => _userTagFilter;
  final _userTagFilter = ValueNotifier<String>(userTagNone);

  Iterable<String> get userTags =>
      cpuProfileStore.lookupProfile(label: userTagNone)?.userTags ??
      const <String>[];

  bool get isToggleFilterActive =>
      toggleFilters.any((filter) => filter.enabled.value);

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

  List<ToggleFilter<CpuStackFrame>>? _toggleFilters;

  int selectedProfilerTabIndex = 0;

  void changeSelectedProfilerTab(int index) {
    selectedProfilerTabIndex = index;
  }

  final transformer = CpuProfileTransformer();

  /// Notifies that the vm profiler flag has changed.
  ValueNotifier<Flag>? get profilerFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profiler);

  ValueNotifier<Flag>? get profileGranularityFlagNotifier =>
      serviceManager.vmFlagManager.flag(vm_flags.profilePeriod);

  /// Whether the profiler is enabled.
  ///
  /// Clients interested in the current value of [profilerFlagNotifier] should
  /// use this getter. Otherwise, clients subscribing to change notifications,
  /// should listen to [profilerFlagNotifier].
  bool get profilerEnabled => offlineController.offlineMode.value
      ? true
      : profilerFlagNotifier?.value.valueAsString == 'true';

  Future<dynamic> enableCpuProfiler() {
    return serviceManager.service!.enableCpuProfiler();
  }

  Future<void> pullAndProcessProfile({
    required int startMicros,
    required int extentMicros,
    required String processId,
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
      cpuProfileData = await serviceManager.service!.getCpuProfile(
        startMicros: startMicros,
        extentMicros: extentMicros,
      );
      await processAndSetData(
        cpuProfileData,
        processId: processId,
        storeAsUserTagNone: true,
        shouldApplyFilters: true,
        shouldRefreshSearchMatches: true,
      );
    }

    if (analyticsScreenId != null) {
      // Pull and process cpu profile data [pullAndProcessHelper] and time the
      // operation for analytics.
      await ga.timeAsync(
        analyticsScreenId!,
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
    required String processId,
    required bool storeAsUserTagNone,
    required bool shouldApplyFilters,
    required bool shouldRefreshSearchMatches,
  }) async {
    _processingNotifier.value = true;
    _dataNotifier.value = null;
    try {
      await transformer.processData(cpuProfileData, processId: processId);
      if (storeAsUserTagNone) {
        cpuProfileStore.storeProfile(cpuProfileData, label: userTagNone);
        cpuProfileStore.storeProfile(
          cpuProfileData,
          time: cpuProfileData.profileMetaData.time,
        );
      }
      if (shouldApplyFilters) {
        cpuProfileData = applyToggleFilters(cpuProfileData);
        await transformer.processData(cpuProfileData, processId: processId);
        if (storeAsUserTagNone) {
          cpuProfileStore.storeProfile(
            cpuProfileData,
            label: _wrapWithFilterSuffix(userTagNone),
          );
        }
      }
      _dataNotifier.value = cpuProfileData;
      if (shouldRefreshSearchMatches) {
        refreshSearchMatches();
      }
      _processingNotifier.value = false;
    } on AssertionError catch (_) {
      _dataNotifier.value = cpuProfileData;
      _processingNotifier.value = false;
      // Rethrow after setting notifiers so that cpu profile data is included
      // in the timeline export.
      rethrow;
    }
  }

  // TODO(kenz): search through previous matches when possible.
  @override
  List<CpuStackFrame> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty) return <CpuStackFrame>[];
    final regexSearch = RegExp(search, caseSensitive: false);
    final matches = <CpuStackFrame>[];
    final currentStackFrames = _dataNotifier.value!.stackFrames.values;
    for (final frame in currentStackFrames) {
      if (frame.name.caseInsensitiveContains(regexSearch) ||
          frame.packageUri.caseInsensitiveContains(regexSearch)) {
        matches.add(frame);
      }
    }
    return matches;
  }

  Future<void> loadAllSamples() async {
    reset();
    await pullAndProcessProfile(
      startMicros: 0,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available.
      extentMicros: maxJsInt,
      processId: 'Load all samples',
    );
  }

  @visibleForTesting
  String generateToggleFilterSuffix() {
    final suffixList = <String>[];
    for (final toggleFilter in toggleFilters) {
      if (toggleFilter.enabled.value) {
        suffixList.add(toggleFilter.name);
      }
    }
    return suffixList.join(',');
  }

  String _wrapWithFilterSuffix(String label) {
    final filterSuffix = generateToggleFilterSuffix();
    return '$label${filterSuffix.isNotEmpty ? '-$filterSuffix' : ''}';
  }

  Future<void> loadAppStartUpProfile() async {
    reset();
    _processingNotifier.value = true;
    _dataNotifier.value = null;

    final storedProfileWithFilters = cpuProfileStore.lookupProfile(
      label: _wrapWithFilterSuffix(appStartUpUserTag),
    );
    if (storedProfileWithFilters != null) {
      _dataNotifier.value = storedProfileWithFilters;
      refreshSearchMatches();
      _processingNotifier.value = false;
      return;
    }

    var appStartUpProfile = cpuProfileStore.lookupProfile(
      label: appStartUpUserTag,
    );
    if (appStartUpProfile == null) {
      final cpuProfile = await serviceManager.service!.getCpuProfile(
        startMicros: 0,
        // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
        // give us all cpu samples we have available.
        extentMicros: maxJsInt,
      );
      appStartUpProfile = CpuProfileData.fromUserTag(
        cpuProfile,
        appStartUpUserTag,
      );
      cpuProfileStore.storeProfile(appStartUpProfile, label: userTagNone);
      cpuProfileStore.storeProfile(appStartUpProfile, label: appStartUpUserTag);
    }

    if (appStartUpProfile.isEmpty) {
      _processingNotifier.value = false;
      _dataNotifier.value = emptyAppStartUpProfile;
      return;
    }

    _userTagFilter.value = appStartUpUserTag;

    if (isToggleFilterActive) {
      final filteredAppStartUpProfile = applyToggleFilters(appStartUpProfile);
      await processAndSetData(
        filteredAppStartUpProfile,
        processId: 'filter app start up profile',
        storeAsUserTagNone: false,
        shouldApplyFilters: false,
        shouldRefreshSearchMatches: true,
      );
      cpuProfileStore.storeProfile(
        filteredAppStartUpProfile,
        label: _wrapWithFilterSuffix(appStartUpUserTag),
      );
      return;
    }

    if (!appStartUpProfile.processed) {
      await transformer.processData(
        appStartUpProfile,
        processId: 'appStartUpProfile',
      );
    }

    _processingNotifier.value = false;
    _dataNotifier.value = appStartUpProfile;
  }

  // TODO(kenz): filter the data before calling this method, or pass in
  // unprocessed data to avoid processing the data twice.
  void loadProcessedData(
    CpuProfileData data, {
    required bool storeAsUserTagNone,
  }) {
    assert(data.processed);
    _dataNotifier.value = data;
    if (storeAsUserTagNone) {
      cpuProfileStore.storeProfile(data, label: userTagNone);
    }
  }

  Future<void> loadDataWithTag(String tag) async {
    _userTagFilter.value = tag;

    _dataNotifier.value = null;
    _processingNotifier.value = true;

    try {
      _dataNotifier.value = await processDataForTag(tag);
    } catch (e) {
      // In the event of an error, reset the data to the original CPU profile.
      final filteredOriginalData = cpuProfileStore.lookupProfile(
        label: _wrapWithFilterSuffix(userTagNone),
      )!;
      _dataNotifier.value = filteredOriginalData;
      throw Exception('Error loading data with tag "$tag": ${e.toString()}');
    } finally {
      _processingNotifier.value = false;
    }
  }

  Future<CpuProfileData> processDataForTag(String tag) async {
    final profileLabel = _wrapWithFilterSuffix(tag);
    final filteredDataForTag = cpuProfileStore.lookupProfile(
      label: profileLabel,
    );
    if (filteredDataForTag != null) {
      if (!filteredDataForTag.processed) {
        await transformer.processData(
          filteredDataForTag,
          processId: profileLabel,
        );
      }
      return filteredDataForTag;
    }

    var data = cpuProfileStore.lookupProfile(label: tag);
    if (data == null) {
      final fullData = cpuProfileStore.lookupProfile(label: userTagNone)!;
      data = CpuProfileData.fromUserTag(fullData, tag);
      cpuProfileStore.storeProfile(data, label: tag);
    }

    data = applyToggleFilters(data);
    if (!data.processed) {
      await transformer.processData(
        data,
        processId: 'data with toggle filters applied',
      );
    }
    cpuProfileStore.storeProfile(data, label: _wrapWithFilterSuffix(tag));

    return data;
  }

  void selectCpuStackFrame(CpuStackFrame? stackFrame) {
    if (stackFrame == dataNotifier.value!.selectedStackFrame) return;
    dataNotifier.value!.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    reset();
    cpuProfileStore.clear();
    await serviceManager.service!.clearSamples();
  }

  void reset({CpuProfileData? data}) {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = data ?? baseStateCpuProfileData;
    _processingNotifier.value = false;
    _userTagFilter.value = userTagNone;
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
    final dataLabel = _wrapWithFilterSuffix(_userTagFilter.value);
    var filteredData = cpuProfileStore.lookupProfile(label: dataLabel);
    if (filteredData == null) {
      final originalData =
          cpuProfileStore.lookupProfile(label: _userTagFilter.value)!;
      filteredData = _filterData(originalData, filter);
      cpuProfileStore.storeProfile(filteredData, label: dataLabel);
    }
    processAndSetData(
      filteredData,
      processId: 'filter $_filterIdentifier',
      storeAsUserTagNone: false,
      shouldApplyFilters: false,
      shouldRefreshSearchMatches: true,
    );
    _filterIdentifier++;
  }

  CpuProfileData _filterData(
    CpuProfileData originalData,
    Filter<CpuStackFrame> filter,
  ) {
    final filterCallback = (CpuStackFrame stackFrame) {
      var shouldInclude = true;
      for (final toggleFilter in filter.toggleFilters!) {
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

  CpuProfileData applyToggleFilters(CpuProfileData data) {
    return _filterData(data, Filter(toggleFilters: toggleFilters));
  }
}
