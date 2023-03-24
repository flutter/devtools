// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/analytics/metrics.dart';
import '../../../../../shared/config_specific/logger/allowed_error.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/auto_dispose.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/trees.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/ui/search.dart';
import '../../../../profiler/cpu_profile_model.dart';
import '../../../../profiler/cpu_profile_service.dart';
import '../../../../profiler/cpu_profiler_controller.dart';
import '../../../../profiler/sampling_rate.dart';
import '../../../performance_controller.dart';
import '../../../performance_model.dart';
import '../../../performance_utils.dart';
import '../../../simple_trace_example.dart';
import '../../flutter_frames/flutter_frame_model.dart';
import 'legacy_event_processor.dart';

final _log = Logger(
  'lib/src/screens/performance/panes/timeline_events/legacy/legacy_events_controller',
);

/// Debugging flag to load sample trace events from [simple_trace_example.dart].
bool debugSimpleTrace = false;

class LegacyTimelineEventsController extends DisposableController
    with SearchControllerMixin<TimelineEvent> {
  LegacyTimelineEventsController(this.performanceController) {
    processor = LegacyEventProcessor(performanceController);
  }

  final PerformanceController performanceController;

  PerformanceData? get data => performanceController.data;

  late final LegacyEventProcessor processor;

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent?> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent?>(null);

  final cpuProfilerController =
      CpuProfilerController(analyticsScreenId: gac.performance);

  /// The tracking index for the first unprocessed trace event collected.
  int _nextTraceIndexToProcess = 0;

  /// The tracking index for the first unprocessed [TimelineEvent] that needs to
  /// be processed and added to the timeline events flame chart.
  int _nextTimelineEventIndexToProcess = 0;

  void init() {
    unawaited(
      allowedError(
        serviceManager.service!.setProfilePeriod(mediumProfilePeriod),
        logError: false,
      ),
    );
  }

  Future<void> processTraceEvents(
    List<TraceEventWrapper> traceEvents, {
    required Map<int, String> threadNamesById,
  }) async {
    if (debugSimpleTrace) {
      traceEvents = simpleTraceEvents['traceEvents']!
          .where(
            (json) => json.containsKey(TraceEvent.timestampKey),
          ) // thread_name events
          .map(
            (e) => TraceEventWrapper(
              TraceEvent(e),
              DateTime.now().microsecondsSinceEpoch,
            ),
          )
          .toList();
    }

    if (data == null) {
      performanceController.initData();
    }
    final _data = data!;
    final traceEventCount = traceEvents.length;

    debugTraceEventCallback(
      () => _log.info(
        'processing traceEvents at startIndex '
        '$_nextTraceIndexToProcess',
      ),
    );

    final processingTraceCount = traceEventCount - _nextTraceIndexToProcess;

    Future<void> processTraceEventsHelper() async {
      await processor.processData(
        traceEvents,
        startIndex: _nextTraceIndexToProcess,
      );
      debugTraceEventCallback(
        () => _log.info(
          'after processing traceEvents at startIndex $_nextTraceIndexToProcess, '
          'and now _nextTraceIndexToProcess = $traceEventCount',
        ),
      );
      _nextTraceIndexToProcess = traceEventCount;

      debugTraceEventCallback(
        () => _log.info(
          'initializing event groups at startIndex '
          '$_nextTimelineEventIndexToProcess',
        ),
      );
      _data.initializeEventGroups(
        threadNamesById,
        startIndex: _nextTimelineEventIndexToProcess,
      );
      debugTraceEventCallback(
        () => _log.info(
          'after initializing event groups at startIndex '
          '$_nextTimelineEventIndexToProcess and now '
          '_nextTimelineEventIndexToProcess = ${_data.timelineEvents.length}',
        ),
      );
      _nextTimelineEventIndexToProcess = _data.timelineEvents.length;
    }

    // Process trace events [processTraceEventsHelper] and time the operation
    // for analytics.
    try {
      await ga.timeAsync(
        gac.performance,
        gac.traceEventProcessingTime,
        asyncOperation: processTraceEventsHelper,
        screenMetricsProvider: () => PerformanceScreenMetrics(
          traceEventCount: processingTraceCount,
        ),
      );
    } on ProcessCancelledException catch (_) {
      // Do nothing for instances of [ProcessCancelledException].
    }
  }

  Future<void> selectTimelineEvent(
    TimelineEvent? event, {
    bool updateProfiler = true,
  }) async {
    final _data = data!;
    if (event == null || _data.selectedEvent == event) return;

    _data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;

    if (event.isUiEvent && updateProfiler) {
      final storedProfile = cpuProfilerController.cpuProfileStore.lookupProfile(
        time: event.time,
      );
      if (storedProfile != null) {
        await cpuProfilerController.processAndSetData(
          storedProfile,
          processId: 'Stored profile for ${event.time}',
          storeAsUserTagNone: true,
          shouldApplyFilters: true,
          shouldRefreshSearchMatches: true,
        );
        _data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      } else if ((!offlineController.offlineMode.value ||
              performanceController.offlinePerformanceData == null) &&
          cpuProfilerController.profilerEnabled) {
        // Fetch a profile if not in offline mode and if the profiler is enabled
        cpuProfilerController.reset();
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: event.time.start!.inMicroseconds,
          extentMicros: event.time.duration.inMicroseconds,
          processId: '${event.traceEvents.first.wrapperId}',
        );
        _data.cpuProfileData = cpuProfilerController.dataNotifier.value;
      }
    }
  }

  Future<void> updateCpuProfileForFrame(FlutterFrame frame) async {
    final storedProfileForFrame =
        cpuProfilerController.cpuProfileStore.lookupProfile(
      time: frame.timeFromEventFlows,
    );
    if (storedProfileForFrame == null) {
      cpuProfilerController.reset();
      if (!offlineController.offlineMode.value &&
          frame.timeFromEventFlows.isWellFormed) {
        await cpuProfilerController.pullAndProcessProfile(
          startMicros: frame.timeFromEventFlows.start!.inMicroseconds,
          extentMicros: frame.timeFromEventFlows.duration.inMicroseconds,
          processId: 'Flutter frame ${frame.id}',
        );
      }
      if (performanceController
              .flutterFramesController.currentFrameBeingSelected !=
          frame) return;
      data?.cpuProfileData = cpuProfilerController.dataNotifier.value;
    } else {
      if (!storedProfileForFrame.processed) {
        await storedProfileForFrame.process(
          transformer: cpuProfilerController.transformer,
          processId: 'Flutter frame ${frame.id} - stored profile ',
        );
      }
      if (performanceController
              .flutterFramesController.currentFrameBeingSelected !=
          frame) return;
      data?.cpuProfileData = storedProfileForFrame.getActive(
        cpuProfilerController.viewType.value,
      );
      cpuProfilerController.loadProcessedData(
        storedProfileForFrame,
        storeAsUserTagNone: true,
      );
    }
  }

  @override
  List<TimelineEvent> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty) return <TimelineEvent>[];
    final regexSearch = RegExp(search, caseSensitive: false);
    final matches = <TimelineEvent>[];
    if (searchPreviousMatches) {
      final List<TimelineEvent> previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.matchesSearchToken(regexSearch)) {
          matches.add(previousMatch);
        }
      }
    } else {
      final events = List<TimelineEvent>.of(data!.timelineEvents);
      for (final event in events) {
        breadthFirstTraversal<TimelineEvent>(
          event,
          action: (TimelineEvent e) {
            if (e.matchesSearchToken(regexSearch)) {
              matches.add(e);
            }
          },
        );
      }
    }
    return matches;
  }

  Future<void> setOfflineData(PerformanceData offlineData) async {
    if (offlineData.cpuProfileData != null) {
      await cpuProfilerController.transformer.processData(
        offlineData.cpuProfileData!,
        processId: 'process offline data',
      );
    }

    if (offlineData.selectedEvent != null) {
      for (var timelineEvent in data!.timelineEvents) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == offlineData.selectedEvent!.name &&
              event.time == offlineData.selectedEvent!.time;
        });
        if (eventToSelect != null) {
          data!
            ..selectedEvent = eventToSelect
            ..cpuProfileData = offlineData.cpuProfileData;
          _selectedTimelineEventNotifier.value = eventToSelect;
          break;
        }
      }
    }

    final offlineCpuProfileData = offlineData.cpuProfileData;
    if (offlineCpuProfileData != null) {
      cpuProfilerController.loadProcessedData(
        CpuProfilePair(
          functionProfile: offlineCpuProfileData,
          // TODO(bkonyi): do we care about offline code profiles?
          codeProfile: null,
        ),
        storeAsUserTagNone: true,
      );
    }
  }

  void clearData() {
    cpuProfilerController.reset();
    processor.reset();
    _nextTraceIndexToProcess = 0;
    _nextTimelineEventIndexToProcess = 0;
    _selectedTimelineEventNotifier.value = null;
  }

  @override
  void dispose() {
    cpuProfilerController.dispose();
    super.dispose();
  }
}
