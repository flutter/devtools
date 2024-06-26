// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/globals.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/filter.dart';
import '../../../shared/utils.dart';
import 'logging_controller_v2.dart';
import 'logging_table_row.dart';
import 'logging_table_v2.dart';

/// A class for holding state and state changes relevant to [LoggingControllerV2]
/// and [LoggingTableV2].
///
/// The [LoggingTableV2] table uses variable height rows. This model caches the
/// relevant heights and offsets so that the row heights only need to be calculated
/// once per parent width.
class LoggingTableModel extends DisposableController
    with ChangeNotifier, DisposerMixin, FilterControllerMixin<LogDataV2> {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(
      callback: (index) => getLogHeight(
        index,
      ),
      progressCallback: (progress) => _cacheLoadProgress.value = progress,
    );

    _retentionLimit = preferences.logging.retentionLimit.value;

    addAutoDisposeListener(
      preferences.logging.retentionLimit,
      _onRetentionLimitUpdate,
    );

    _retentionLimit = preferences.logging.retentionLimit.value;
    subscribeToFilterChanges();
  }

  final _logs = ListQueue<_LogEntry>();
  final _filteredLogs = ListQueue<_FilteredLogEntry>();

  final _selectedLogs = ListQueue<LogDataV2>();
  late int _retentionLimit;

  late final InterruptableChunkWorker _worker;

  /// Represents the state of reloading the height caches.
  ///
  /// When null, then the cache is not loading.
  /// When double, then the value is represents how much progress has been made.
  ValueListenable<double?> get cacheLoadProgress => _cacheLoadProgress;
  final _cacheLoadProgress = ValueNotifier<double?>(null);

  void _onRetentionLimitUpdate() {
    _retentionLimit = preferences.logging.retentionLimit.value;
    while (_logs.length > _retentionLimit) {
      _trimOneOutOfRetentionLog();
    }
    _recalculateOffsets();
    notifyListeners();
  }

  void _recalculateOffsets() {
    double runningOffset = 0.0;
    for (var i = 0; i < _filteredLogs.length; i++) {
      _filteredLogs.elementAt(i).offset = runningOffset;
      runningOffset += getFilteredLogHeight(i);
    }
  }

  @override
  void dispose() {
    _cacheLoadProgress.dispose();
    _worker.dispose();
    super.dispose();
  }

  @override
  void filterData(Filter<LogDataV2> filter) {
    super.filterData(filter);

    _filteredLogs
      ..clear()
      ..addAll(
        _logs.where(_filterCallback).map((e) => _FilteredLogEntry(e)).toList(),
      );
    notifyListeners();
  }

  bool _filterCallback(_LogEntry entry) {
    final filter = activeFilter.value;

    final log = entry.log;
    final filteredOutByToggleFilters = filter.toggleFilters.any(
      (toggleFilter) =>
          toggleFilter.enabled.value && !toggleFilter.includeCallback(log),
    );
    if (filteredOutByToggleFilters) return false;

    final queryFilter = filter.queryFilter;
    if (!queryFilter.isEmpty) {
      final filteredOutByQueryFilterArgument = queryFilter
          .filterArguments.values
          .any((argument) => !argument.matchesValue(log));
      if (filteredOutByQueryFilterArgument) return false;

      if (filter.queryFilter.substringExpressions.isNotEmpty) {
        for (final substring in filter.queryFilter.substringExpressions) {
          final matchesKind = log.kind.caseInsensitiveContains(substring);
          if (matchesKind) return true;

          final matchesSummary = log.summary != null &&
              log.summary!.caseInsensitiveContains(substring);
          if (matchesSummary) return true;

          final matchesDetails = log.details != null &&
              log.details!.caseInsensitiveContains(substring);
          if (matchesDetails) return true;
        }
        return false;
      }
    }

    return true;
  }

  double get tableWidth => _tableWidth;

  /// Update the width of the table.
  ///
  /// If different from the last width, this will flush all of the calculated heights, and recalculate their heights
  /// in the background.
  set tableWidth(double width) {
    if (width != _tableWidth) {
      _tableWidth = width;
      for (final e in _logs) {
        e.height = null;
      }
      for (final e in _filteredLogs) {
        e.offset = null;
      }
      unawaited(_preFetchRowHeights());
    }
  }

  /// Get the filtered log at [index].
  LogDataV2 filteredLogAt(int index) =>
      _filteredLogs.elementAt(index).logEntry.log;

  double _tableWidth = 0.0;

  /// The total number of logs being held by the [LoggingTableModel].
  int get logCount => _logs.length;

  /// The number of filtered logs.
  int get filteredLogCount => _filteredLogs.length;

  /// The number of selected logs.
  int get selectedLogCount => _selectedLogs.length;

  /// Add a log to the list of tracked logs.
  void add(LogDataV2 log) {
    final newEntry = _LogEntry(log);
    _logs.add(newEntry);
    getLogHeight(
      _logs.length - 1,
    );
    _trimOneOutOfRetentionLog();

    if (!_filterCallback(newEntry)) {
      // Only add the log to filtered logs if it matches the filter.
      return;
    }
    _filteredLogs.add(_FilteredLogEntry(newEntry));
    notifyListeners();
  }

  void _trimOneOutOfRetentionLog() {
    if (_logs.length > _retentionLimit) {
      if (identical(_logs.first.log, _filteredLogs.first.logEntry.log)) {
        // Remove a filtered log if it is about to go out of retention.
        _filteredLogs.removeFirst();
      }

      // Remove the log that has just gone out of retention.
      _logs.removeFirst();
    }
  }

  /// Clears all of the logs from the model.
  void clear() {
    _logs.clear();
    _filteredLogs.clear();
    notifyListeners();
  }

  /// Get the offset of a filtered log, at [index], from the top of the list of filtered logs.
  double filteredLogOffsetAt(int _) {
    throw Exception('Implement this when needed');
  }

  double getLogHeight(int index) {
    final entry = _logs.elementAt(index);
    final cachedHeight = entry.height;
    if (cachedHeight != null) return cachedHeight;
    final height = LoggingTableRow.calculateRowHeight(
      entry.log,
      _tableWidth,
    );
    entry.height = height;
    return height;
  }

  /// Get the height of a filtered Log at [index].
  double getFilteredLogHeight(int index) {
    final filteredLog = _filteredLogs.elementAt(index);
    final cachedHeight = filteredLog.logEntry.height;
    if (cachedHeight != null) return cachedHeight;

    final height = LoggingTableRow.calculateRowHeight(
      filteredLog.logEntry.log,
      _tableWidth,
    );
    filteredLog.logEntry.height = height;
    return height;
  }

  Future<bool> _preFetchRowHeights() async {
    final didComplete = await _worker.doWork(_logs.length);
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    _recalculateOffsets();
    return didComplete;
  }
}

class _LogEntry {
  _LogEntry(this.log);
  final LogDataV2 log;
  double? height;
}

class _FilteredLogEntry {
  _FilteredLogEntry(this.logEntry);
  final _LogEntry logEntry;
  double? offset;
}
