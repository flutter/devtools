// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/analytics/metrics.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/trees.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/ui/search.dart';
import '../../../performance_controller.dart';
import '../../../performance_model.dart';
import '../../../performance_utils.dart';
import '../../../simple_trace_example.dart';
import 'legacy_event_processor.dart';

final _log = Logger('legacy_events_controller');

/// Debugging flag to load sample trace events from [simple_trace_example.dart].
bool debugSimpleTrace = false;

class LegacyTimelineEventsController with SearchControllerMixin<TimelineEvent> {
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

  /// The tracking index for the first unprocessed trace event collected.
  int _nextTraceIndexToProcess = 0;

  /// The tracking index for the first unprocessed [TimelineEvent] that needs to
  /// be processed and added to the timeline events flame chart.
  int _nextTimelineEventIndexToProcess = 0;

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

  Future<void> selectTimelineEvent(TimelineEvent? event) async {
    final _data = data!;
    if (event == null || _data.selectedEvent == event) return;

    _data.selectedEvent = event;
    _selectedTimelineEventNotifier.value = event;
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

  Future<void> setOfflineData(PerformanceData offlineData) {
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
  }

  void clearData() {
    processor.reset();
    _nextTraceIndexToProcess = 0;
    _nextTimelineEventIndexToProcess = 0;
    _selectedTimelineEventNotifier.value = null;
  }
}
