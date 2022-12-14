// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_flags.dart' as vm_flags;
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/analytics/metrics.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profile_transformer.dart';

enum CpuProfilerViewType {
  function,
  code;

  @override
  String toString() {
    return this == function ? 'Function' : 'Code';
  }
}

enum CpuProfilerTagType {
  user,
  vm,
}

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

  /// Special tags that represent profiles broken down by user or VM tags.
  static const groupByUserTag = '#group-by-user-tag';
  static const groupByVmTag = '#group-by-vm-tag';

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
      cpuProfileStore
          .lookupProfile(
            label: userTagNone,
          )
          ?.functionProfile
          .userTags ??
      const <String>[];

  ValueListenable<CpuProfilerViewType> get viewType => _viewType;
  final _viewType =
      ValueNotifier<CpuProfilerViewType>(CpuProfilerViewType.function);

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

  ValueNotifier<Flag>? get profilePeriodFlag =>
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

    var cpuProfiles = CpuProfilePair(
      functionProfile: baseStateCpuProfileData,
      codeProfile: null,
    );

    _dataNotifier.value = null;

    Future<void> pullAndProcessHelper() async {
      // TODO(kenz): add a cancel button to the processing UI in case pulling a
      // large payload from the vm service takes a long time.
      cpuProfiles = await serviceManager.service!.getCpuProfile(
        startMicros: startMicros,
        extentMicros: extentMicros,
      );
      await processAndSetData(
        cpuProfiles,
        processId: processId,
        storeAsUserTagNone: true,
        shouldApplyFilters: true,
        shouldRefreshSearchMatches: true,
      );
    }

    try {
      if (analyticsScreenId != null) {
        // Pull and process cpu profile data [pullAndProcessHelper] and time the
        // operation for analytics.

        await ga.timeAsync(
          analyticsScreenId!,
          gac.cpuProfileProcessingTime,
          asyncOperation: pullAndProcessHelper,
          screenMetricsProvider: () => ProfilerScreenMetrics(
            cpuSampleCount: cpuProfiles.profileMetaData.sampleCount,
            cpuStackDepth: cpuProfiles.profileMetaData.stackDepth,
          ),
        );
      } else {
        await pullAndProcessHelper();
      }
    } on ProcessCancelledException catch (_) {
      // Do nothing for instances of [ProcessCancelledException].
    }
  }

  Future<CpuProfilePair> _processDataHelper(
    CpuProfilePair cpuProfiles, {
    required String processId,
    required bool storeAsUserTagNone,
    required bool shouldApplyFilters,
    required bool shouldRefreshSearchMatches,
    required bool isCodeProfile,
  }) async {
    await cpuProfiles.process(
      transformer: transformer,
      processId: processId,
    );
    if (storeAsUserTagNone) {
      cpuProfileStore.storeProfile(
        cpuProfiles,
        label: userTagNone,
      );
      cpuProfileStore.storeProfile(
        cpuProfiles,
        time: cpuProfiles.profileMetaData.time,
      );
    }
    if (shouldApplyFilters) {
      cpuProfiles = applyToggleFilters(cpuProfiles);
      await cpuProfiles.process(
        transformer: transformer,
        processId: processId,
      );
      if (storeAsUserTagNone) {
        cpuProfileStore.storeProfile(
          cpuProfiles,
          label: _wrapWithFilterSuffix(userTagNone),
        );
      }
    }
    return cpuProfiles;
  }

  /// Processes [cpuProfiles] and sets the data for the controller.
  ///
  /// If `storeAsUserTagNone` is true, the processed data will be stored as the
  /// original data, where no user tag filter has been applied.
  Future<void> processAndSetData(
    CpuProfilePair cpuProfiles, {
    required String processId,
    required bool storeAsUserTagNone,
    required bool shouldApplyFilters,
    required bool shouldRefreshSearchMatches,
  }) async {
    _dataNotifier.value = null;
    final type = viewType.value;
    CpuProfileData cpuProfileData = cpuProfiles.getActive(type);
    try {
      _processingNotifier.value = true;
      cpuProfileData = await _processDataHelper(
        cpuProfiles,
        processId: processId,
        storeAsUserTagNone: storeAsUserTagNone,
        shouldApplyFilters: shouldApplyFilters,
        shouldRefreshSearchMatches: shouldRefreshSearchMatches,
        isCodeProfile: type == CpuProfilerViewType.code,
      ).then((p) => p.getActive(type));

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

  @override
  List<CpuStackFrame> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty) return <CpuStackFrame>[];
    final regexSearch = RegExp(search, caseSensitive: false);
    final matches = <CpuStackFrame>[];
    if (searchPreviousMatches) {
      final previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.name.caseInsensitiveContains(regexSearch) ||
            previousMatch.packageUri.caseInsensitiveContains(regexSearch)) {
          matches.add(previousMatch);
        }
      }
    } else {
      final currentStackFrames = _dataNotifier.value!.stackFrames.values;
      for (final frame in currentStackFrames) {
        if (frame.name.caseInsensitiveContains(regexSearch) ||
            frame.packageUri.caseInsensitiveContains(regexSearch)) {
          matches.add(frame);
        }
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
      _dataNotifier.value = storedProfileWithFilters.getActive(viewType.value);
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
      appStartUpProfile = CpuProfilePair.fromUserTag(
        cpuProfile,
        appStartUpUserTag,
      );
      cpuProfileStore.storeProfile(
        appStartUpProfile,
        label: userTagNone,
      );
      cpuProfileStore.storeProfile(
        appStartUpProfile,
        label: appStartUpUserTag,
      );
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
      await appStartUpProfile.process(
        transformer: transformer,
        processId: 'appStartUpProfile',
      );
    }

    _processingNotifier.value = false;
    _dataNotifier.value = appStartUpProfile.getActive(viewType.value);
  }

  // TODO(kenz): filter the data before calling this method, or pass in
  // unprocessed data to avoid processing the data twice.
  void loadProcessedData(
    CpuProfilePair data, {
    required bool storeAsUserTagNone,
  }) {
    assert(data.processed);
    _dataNotifier.value = data.getActive(viewType.value);
    if (storeAsUserTagNone) {
      cpuProfileStore.storeProfile(
        data,
        label: userTagNone,
      );
    }
  }

  Future<void> loadDataWithTag(String tag) async {
    _userTagFilter.value = tag;

    _dataNotifier.value = null;
    _processingNotifier.value = true;

    try {
      _dataNotifier.value = await processDataForTag(tag).then(
        (e) => e.getActive(viewType.value),
      );
    } catch (e) {
      // In the event of an error, reset the data to the original CPU profile.
      final filteredOriginalData = cpuProfileStore.lookupProfile(
        label: _wrapWithFilterSuffix(userTagNone),
      )!;
      _dataNotifier.value = filteredOriginalData.getActive(viewType.value);
      throw Exception('Error loading data with tag "$tag": ${e.toString()}');
    } finally {
      _processingNotifier.value = false;
    }
  }

  Future<CpuProfilePair> processDataForTag(String tag) async {
    final profileLabel = _wrapWithFilterSuffix(tag);
    final filteredDataForTag = cpuProfileStore.lookupProfile(
      label: profileLabel,
    );
    if (filteredDataForTag != null) {
      if (!filteredDataForTag.processed) {
        await filteredDataForTag.process(
          transformer: transformer,
          processId: profileLabel,
        );
      }
      return filteredDataForTag;
    }
    var data = cpuProfileStore.lookupProfile(
      label: tag,
    );
    if (data == null) {
      final fullData = cpuProfileStore.lookupProfile(
        label: userTagNone,
      )!;

      data = tag == groupByUserTag || tag == groupByVmTag
          ? CpuProfilePair.withTagRoots(
              fullData,
              tag == groupByUserTag
                  ? CpuProfilerTagType.user
                  : CpuProfilerTagType.vm,
            )
          : CpuProfilePair.fromUserTag(fullData, tag);
      cpuProfileStore.storeProfile(
        data,
        label: tag,
      );
    }

    data = applyToggleFilters(data);
    if (!data.processed) {
      await data.process(
        transformer: transformer,
        processId: 'data with toggle filters applied',
      );
    }
    cpuProfileStore.storeProfile(
      data,
      label: _wrapWithFilterSuffix(tag),
    );

    return data;
  }

  void updateView(CpuProfilerViewType view) {
    _viewType.value = view;
    _dataNotifier.value = cpuProfileStore
        .lookupProfile(
          label: _wrapWithFilterSuffix(_userTagFilter.value),
        )
        ?.getActive(view);
  }

  void selectCpuStackFrame(CpuStackFrame? stackFrame) {
    if (stackFrame == dataNotifier.value!.selectedStackFrame) return;
    dataNotifier.value!.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    reset();
    await serviceManager.service!.clearSamples();
  }

  void reset({CpuProfileData? data}) {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = data ?? baseStateCpuProfileData;
    _processingNotifier.value = false;
    _userTagFilter.value = userTagNone;
    transformer.reset();
    cpuProfileStore.clear();
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
    var filteredData = cpuProfileStore.lookupProfile(
      label: dataLabel,
    );
    if (filteredData == null) {
      final originalData = cpuProfileStore.lookupProfile(
        label: _userTagFilter.value,
      )!;
      filteredData = _filterData(originalData, filter);
      cpuProfileStore.storeProfile(
        filteredData,
        label: dataLabel,
      );
    }
    unawaited(
      processAndSetData(
        filteredData,
        processId: 'filter $_filterIdentifier',
        storeAsUserTagNone: false,
        shouldApplyFilters: false,
        shouldRefreshSearchMatches: true,
      ),
    );
    _filterIdentifier++;
  }

  CpuProfilePair _filterData(
    CpuProfilePair originalData,
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
    return CpuProfilePair.filterFrom(originalData, filterCallback);
  }

  CpuProfilePair applyToggleFilters(CpuProfilePair data) {
    return _filterData(data, Filter(toggleFilters: toggleFilters));
  }
}
