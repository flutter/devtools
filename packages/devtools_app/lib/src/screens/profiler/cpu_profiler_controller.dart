// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../../service/vm_flags.dart' as vm_flags;
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/analytics/metrics.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import 'common.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_service.dart';
import 'cpu_profile_transformer.dart';
import 'panes/method_table/method_table_controller.dart';

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

enum CpuProfilerBusyStatus {
  fetching,
  processing,
  none;

  String get display => name.toSentenceCase();
}

class CpuProfilerController extends DisposableController
    with
        SearchControllerMixin<CpuStackFrame>,
        FilterControllerMixin<CpuStackFrame>,
        AutoDisposeControllerMixin {
  CpuProfilerController() {
    subscribeToFilterChanges();
  }

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

  /// The store of cached CPU profiles for the currently selected isolate.
  ///
  /// The stored profiles are not guaranteed to be processed.
  CpuProfileStore get cpuProfileStore =>
      _cpuProfileStoreByIsolateId.putIfAbsent(
        serviceConnection
                .serviceManager.isolateManager.selectedIsolate.value?.id ??
            '',
        () => CpuProfileStore(),
      );

  /// Store of cached CPU profiles for each isolate.
  final _cpuProfileStoreByIsolateId = <String, CpuProfileStore>{};

  late final methodTableController =
      MethodTableController(dataNotifier: dataNotifier);

  /// Notifies that new cpu profile data is available.
  ValueListenable<CpuProfileData?> get dataNotifier => _dataNotifier;
  final _dataNotifier = ValueNotifier<CpuProfileData?>(baseStateCpuProfileData);

  /// The current busy state of the cpu profiler.
  ValueListenable<CpuProfilerBusyStatus> get profilerBusyStatus =>
      _profilerBusyStatus;
  final _profilerBusyStatus =
      ValueNotifier<CpuProfilerBusyStatus>(CpuProfilerBusyStatus.none);

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

  /// The toggle filters available for the CPU profiler.
  @override
  List<ToggleFilter<CpuStackFrame>> createToggleFilters() => [
        ToggleFilter<CpuStackFrame>(
          name: 'Hide Native code',
          includeCallback: (stackFrame) => !stackFrame.isNative,
          enabledByDefault: true,
        ),
        ToggleFilter<CpuStackFrame>(
          name: 'Hide core Dart libraries',
          includeCallback: (stackFrame) => !stackFrame.isDartCore,
        ),
        if (serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
            true)
          ToggleFilter<CpuStackFrame>(
            name: 'Hide core Flutter libraries',
            includeCallback: (stackFrame) => !stackFrame.isFlutterCore,
          ),
      ];

  static const uriFilterId = 'cpu-profiler-uri-filter';

  @override
  Map<String, QueryFilterArgument> createQueryFilterArgs() => {
        uriFilterId: QueryFilterArgument(keys: ['uri', 'u']),
      };

  int selectedProfilerTabIndex = 0;

  ProfilerTab selectedProfilerTab = ProfilerTab.bottomUp;

  void changeSelectedProfilerTab(int index, ProfilerTab tab) {
    selectedProfilerTabIndex = index;

    // The method table has a different search field than the rest of the
    // profiler tabs. This is because the method table shows data of type
    // [MethodTableGraphNode] and the other profiler tabs show data of type
    // [CpuStackFrame].
    //
    // In order to ensure a consistent search experience across profiler tabs,
    // update the appropriate controller's search value to be consistent when
    // switching to or from the method table tab.
    final oldTabWasMethodTable = selectedProfilerTab == ProfilerTab.methodTable;
    final newTabIsMethodTable = tab == ProfilerTab.methodTable;
    selectedProfilerTab = tab;
    if (oldTabWasMethodTable != newTabIsMethodTable) {
      if (newTabIsMethodTable) {
        methodTableController.search = search;
      } else {
        search = methodTableController.search;
      }
    }
  }

  final transformer = CpuProfileTransformer();

  /// Notifies that the vm profiler flag has changed.
  ValueNotifier<Flag>? get profilerFlagNotifier =>
      serviceConnection.vmFlagManager.flag(vm_flags.profiler) ??
      ValueNotifier<Flag>(Flag());

  ValueNotifier<Flag>? get profilePeriodFlag =>
      serviceConnection.vmFlagManager.flag(vm_flags.profilePeriod);

  /// Whether the profiler is enabled.
  ///
  /// Clients interested in the current value of [profilerFlagNotifier] should
  /// use this getter. Otherwise, clients subscribing to change notifications,
  /// should listen to [profilerFlagNotifier].
  bool get profilerEnabled => offlineController.offlineMode.value
      ? true
      : profilerFlagNotifier?.value.valueAsString == 'true';

  Future<Response> enableCpuProfiler() {
    return serviceConnection.serviceManager.service!.enableCpuProfiler();
  }

  Future<void> pullAndProcessProfile({
    required int startMicros,
    required int extentMicros,
    required String processId,
  }) async {
    if (!profilerEnabled) return;
    assert(_dataNotifier.value != null);
    assert(_profilerBusyStatus.value == CpuProfilerBusyStatus.none);

    var cpuProfiles = CpuProfilePair(
      functionProfile: baseStateCpuProfileData,
      codeProfile: null,
    );

    _dataNotifier.value = null;

    Future<void> pullAndProcessHelper() async {
      // TODO(kenz): add a cancel button to the processing UI in case pulling a
      // large payload from the vm service takes a long time.
      _profilerBusyStatus.value = CpuProfilerBusyStatus.fetching;
      cpuProfiles =
          await serviceConnection.serviceManager.service!.getCpuProfile(
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
      // Pull and process cpu profile data [pullAndProcessHelper] and time the
      // operation for analytics.
      await ga.timeAsync(
        gac.cpuProfiler,
        gac.CpuProfilerEvents.cpuProfileProcessingTime.name,
        asyncOperation: pullAndProcessHelper,
        screenMetricsProvider: () => ProfilerScreenMetrics(
          cpuSampleCount: cpuProfiles.profileMetaData.sampleCount,
          cpuStackDepth: cpuProfiles.profileMetaData.stackDepth,
        ),
      );
    } on ProcessCancelledException catch (_) {
      // Do nothing for instances of [ProcessCancelledException].
    }
  }

  Future<CpuProfilePair> _processDataHelper(
    CpuProfilePair cpuProfiles, {
    required String processId,
    required bool storeAsUserTagNone,
    required bool shouldApplyFilters,
  }) async {
    assert(_profilerBusyStatus.value == CpuProfilerBusyStatus.processing);
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
      cpuProfiles = _filterData(cpuProfiles);
    }

    await cpuProfiles.process(
      transformer: transformer,
      processId: processId,
    );
    if (storeAsUserTagNone && shouldApplyFilters) {
      cpuProfileStore.storeProfile(
        cpuProfiles,
        label: _wrapWithFilterTag(userTagNone),
      );
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
    _profilerBusyStatus.value = CpuProfilerBusyStatus.processing;
    final type = viewType.value;
    CpuProfileData cpuProfileData = cpuProfiles.getActive(type);
    try {
      cpuProfileData = await _processDataHelper(
        cpuProfiles,
        processId: processId,
        storeAsUserTagNone: storeAsUserTagNone,
        shouldApplyFilters: shouldApplyFilters,
      ).then((p) => p.getActive(type));

      _dataNotifier.value = cpuProfileData;
      if (shouldRefreshSearchMatches) {
        refreshSearchMatches();
      }
      _profilerBusyStatus.value = CpuProfilerBusyStatus.none;
    } on AssertionError catch (_) {
      _dataNotifier.value = cpuProfileData;
      _profilerBusyStatus.value = CpuProfilerBusyStatus.none;
      // Rethrow after setting notifiers so that cpu profile data is included
      // in the timeline export.
      rethrow;
    }
  }

  @override
  Iterable<CpuStackFrame> get currentDataToSearchThrough =>
      _dataNotifier.value!.stackFrames.values;

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

  /// Looks up a profile from the [cpuProfileStore] and processes the data if it
  /// has not already been processed.
  ///
  /// [createIfAbsent] - an optional callback to create a [CpuProfilePair] that
  /// will be stored for [label] if one does not already exist.
  /// [shouldApplyFilters] - whether the active filter should be applied to the
  /// looked up [CpuProfilePair].
  Future<CpuProfilePair?> lookupProfileAndProcess({
    required String label,
    CpuProfilePair Function()? createIfAbsent,
    bool shouldApplyFilters = false,
  }) async {
    var storedProfile = cpuProfileStore.lookupProfile(label: label);
    if (storedProfile == null) {
      if (createIfAbsent != null) {
        final newProfile = createIfAbsent();
        cpuProfileStore.storeProfile(newProfile, label: label);
        storedProfile = newProfile;
      } else {
        return null;
      }
    }

    if (shouldApplyFilters && isFilterActive) {
      final storedFilteredProfile = cpuProfileStore.lookupProfile(
        label: _wrapWithFilterTag(label),
      );
      storedProfile = storedFilteredProfile ?? _filterData(storedProfile);
    }

    if (!storedProfile.processed) {
      await storedProfile.process(
        transformer: transformer,
        processId: 'lookupProfileAndProcess $label',
      );
      // Overwrite the profile store with the processed profile so that we do not
      // process this profile again.
      cpuProfileStore.storeProfile(
        storedProfile,
        label: shouldApplyFilters ? _wrapWithFilterTag(label) : label,
      );
    }
    return storedProfile;
  }

  String _wrapWithFilterTag(String label, {String? filterTag}) {
    filterTag ??= activeFilterTag();
    return '$label${filterTag.isNotEmpty ? '-$filterTag' : ''}';
  }

  Future<void> loadAppStartUpProfile() async {
    Future<void> loadAppStartUpProfileHelper() async {
      // Look up the stored app start up profiles before calling [reset]. This
      // will save us the work of processing the startup profiles again if we have
      // already processed them once.
      var appStartUpProfile = await lookupProfileAndProcess(
        label: appStartUpUserTag,
      );
      final appStartUpProfileWithFilters = await lookupProfileAndProcess(
        label: _wrapWithFilterTag(appStartUpUserTag),
      );

      reset();

      _dataNotifier.value = null;

      if (appStartUpProfileWithFilters != null) {
        _dataNotifier.value =
            appStartUpProfileWithFilters.getActive(viewType.value);
        refreshSearchMatches();
        return;
      }

      if (appStartUpProfile == null) {
        final cpuProfile =
            await serviceConnection.serviceManager.service!.getCpuProfile(
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
        _dataNotifier.value = emptyAppStartUpProfile;
        return;
      }

      _userTagFilter.value = appStartUpUserTag;

      if (isFilterActive) {
        final filteredAppStartUpProfile = _filterData(appStartUpProfile);
        await processAndSetData(
          filteredAppStartUpProfile,
          processId: 'filter app start up profile',
          storeAsUserTagNone: false,
          shouldApplyFilters: false,
          shouldRefreshSearchMatches: true,
        );
        cpuProfileStore.storeProfile(
          filteredAppStartUpProfile,
          label: _wrapWithFilterTag(appStartUpUserTag),
        );
        return;
      }

      if (!appStartUpProfile.processed) {
        await appStartUpProfile.process(
          transformer: transformer,
          processId: 'appStartUpProfile',
        );
      }

      _dataNotifier.value = appStartUpProfile.getActive(viewType.value);
    }

    _profilerBusyStatus.value = CpuProfilerBusyStatus.processing;
    await loadAppStartUpProfileHelper();
    _profilerBusyStatus.value = CpuProfilerBusyStatus.none;
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
    _profilerBusyStatus.value = CpuProfilerBusyStatus.processing;

    try {
      _dataNotifier.value = await processDataForTag(tag).then(
        (e) => e.getActive(viewType.value),
      );
    } catch (e, stackTrace) {
      // In the event of an error, reset the data to the original CPU profile.
      final filteredOriginalData = await lookupProfileAndProcess(
        label: _wrapWithFilterTag(userTagNone),
      );
      _dataNotifier.value = filteredOriginalData!.getActive(viewType.value);
      Error.throwWithStackTrace(
        Exception('Error loading data with tag "$tag": ${e.toString()}'),
        stackTrace,
      );
    } finally {
      _profilerBusyStatus.value = CpuProfilerBusyStatus.none;
    }
  }

  Future<CpuProfilePair> processDataForTag(String tag) async {
    final profileLabel = _wrapWithFilterTag(tag);
    final filteredDataForTag = await lookupProfileAndProcess(
      label: profileLabel,
    );
    if (filteredDataForTag != null) return filteredDataForTag;

    final data = await lookupProfileAndProcess(
      label: tag,
      createIfAbsent: () {
        final fullData = cpuProfileStore.lookupProfile(label: userTagNone)!;
        final tagType = tag == groupByUserTag
            ? CpuProfilerTagType.user
            : CpuProfilerTagType.vm;
        final data = tag == groupByUserTag || tag == groupByVmTag
            ? CpuProfilePair.withTagRoots(
                fullData,
                tagType,
              )
            : CpuProfilePair.fromUserTag(fullData, tag);
        cpuProfileStore.storeProfile(data, label: tag);
        return data;
      },
      shouldApplyFilters: true,
    );
    return data!;
  }

  void updateViewForType(CpuProfilerViewType type) {
    _viewType.value = type;
    _dataNotifier.value = cpuProfileStore
        .lookupProfile(
          label: _wrapWithFilterTag(_userTagFilter.value),
        )
        ?.getActive(type);
  }

  void selectCpuStackFrame(CpuStackFrame? stackFrame) {
    if (stackFrame == dataNotifier.value!.selectedStackFrame) return;
    dataNotifier.value!.selectedStackFrame = stackFrame;
    _selectedCpuStackFrameNotifier.value = stackFrame;
  }

  Future<void> clear() async {
    reset();
    await serviceConnection.serviceManager.service!.clearSamples();
  }

  void reset({CpuProfileData? data}) {
    _selectedCpuStackFrameNotifier.value = null;
    _dataNotifier.value = data ?? baseStateCpuProfileData;
    _profilerBusyStatus.value = CpuProfilerBusyStatus.none;
    _userTagFilter.value = userTagNone;
    transformer.reset();
    cpuProfileStore.clear();
    methodTableController.reset(shouldResetSearch: true);
    resetSearch();
  }

  @override
  void dispose() {
    // [methodTableController] needs to be disposed before [_dataNotifier] since
    // it is late initialized with a reference to [_dataNotifier].
    methodTableController.dispose();
    _dataNotifier.dispose();
    _selectedCpuStackFrameNotifier.dispose();
    _profilerBusyStatus.dispose();
    methodTableController.dispose();
    super.dispose();
  }

  /// Tracks the identifier for the attempt to filter the data.
  ///
  /// We use this to prevent multiple filter calls from processing data at the
  /// same time.
  int _filterIdentifier = 0;

  @override
  void filterData(Filter<CpuStackFrame> filter) {
    super.filterData(filter);
    final dataForCurrentTag = cpuProfileStore.lookupProfile(
      label: _userTagFilter.value,
    );
    if (dataForCurrentTag == null) {
      // We have nothing to filter from, so bail out early.
      return;
    }

    CpuProfilePair? filteredData;
    if (filter.isEmpty) {
      // If the filter is empty, no need to filter. Just look up the current
      // unfiltered profile.
      filteredData = dataForCurrentTag;
    } else {
      // Lookup the cpu profile from the cached [cpuProfileStore] if present.
      final dataLabel = _wrapWithFilterTag(_userTagFilter.value);
      filteredData = cpuProfileStore.lookupProfile(
        label: dataLabel,
      );

      if (filteredData == null) {
        // TODO(https://github.com/flutter/devtools/issues/5203): optimize
        // filtering by filtering from already filtered data when possible. The
        // below code is intentionally left in comments for reference.
        // CpuProfilePair? filterFrom;
        // if (!filter.queryFilter.isEmpty) {
        //   // Lookup the cpu profile without the query filter, and filter from
        //   // that profile to optimize performance.
        //   final filterTagWithoutQuery = activeFilterTag()
        //       .split(FilterControllerMixin.filterTagSeparator)
        //       .first;
        //   final label = _wrapWithFilterTag(
        //     _userTagFilter.value,
        //     filterTag: filterTagWithoutQuery,
        //   );
        //   filterFrom = cpuProfileStore.lookupProfile(
        //     label: label,
        //   );
        // }

        final filterFrom = dataForCurrentTag;
        filteredData = _filterData(filterFrom, filter: filter);
        cpuProfileStore.storeProfile(
          filteredData,
          label: dataLabel,
        );
      }
    }
    unawaited(
      processAndSetData(
        filteredData,
        processId: 'filter $_filterIdentifier',
        storeAsUserTagNone: false,
        // Filters are already applied before this call to [processAndSetData].
        shouldApplyFilters: false,
        shouldRefreshSearchMatches: true,
      ),
    );
    _filterIdentifier++;
  }

  CpuProfilePair _filterData(
    CpuProfilePair originalData, {
    Filter<CpuStackFrame>? filter,
  }) {
    filter ??= activeFilter.value;
    bool filterCallback(CpuStackFrame stackFrame) {
      for (final toggleFilter in filter!.toggleFilters) {
        if (toggleFilter.enabled.value &&
            !toggleFilter.includeCallback(stackFrame)) {
          return false;
        }
      }

      final queryFilter = filter.queryFilter;
      if (!queryFilter.isEmpty) {
        final uriArg = queryFilter.filterArguments[uriFilterId];
        if (uriArg != null &&
            !uriArg.matchesValue(
              stackFrame.packageUri,
              substringMatch: true,
            )) {
          return false;
        }

        if (queryFilter.substrings.isNotEmpty) {
          for (final substring in queryFilter.substrings) {
            bool matches(String? stringToMatch) {
              return stringToMatch?.caseInsensitiveContains(substring) ?? false;
            }

            if (matches(stackFrame.name)) return true;
            if (matches(stackFrame.packageUri)) return true;
          }
          return false;
        }
      }

      return true;
    }

    return CpuProfilePair.filterFrom(originalData, filterCallback);
  }
}
