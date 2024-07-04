// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/globals.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/filter.dart';
import '../../../shared/utils.dart';
import 'logging_controller_v2.dart';
import 'logging_table_row.dart';
import 'logging_table_v2.dart';

const _gcLogKind = 'gc';

final _verboseFlutterFrameworkLogKinds = <String>{
  FlutterEvent.firstFrame,
  FlutterEvent.frameworkInitialization,
  FlutterEvent.frame,
  FlutterEvent.imageSizesForFrame,
};

final _verboseFlutterServiceLogKinds = <String>{
  FlutterEvent.serviceExtensionStateChanged,
};

// TODO(danchevalier): implement accessory logs.
/// Log kinds to show without a summary in the table.
// final _hideSummaryLogKinds = <String>{
//   FlutterEvent.firstFrame,
//   FlutterEvent.frameworkInitialization,
// };

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

  /// [FilterControllerMixin] uses [ListValueNotifier] which isn't well optimized to the
  /// retention limit behavior that [LoggingTableModel] uses. So we use
  /// [ListQueue] here to facilitate those actions. Then instead of
  /// using [FilterControllerMixin.filteredLogs] in [FilterControllerMixin.filterData],
  /// we use [_filteredLogs]. After any changes are done to [_filteredLogs], [notifyListeners]
  /// must be manually triggered, since the listener behaviour is accomplished by the
  /// [LoggingTableModel] being a [ChangeNotifier].
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
    _recalculateOffsets();
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
      for (final log in _logs) {
        log.height = null;
      }
      for (final log in _filteredLogs) {
        log.offset = null;
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
    getLogHeight(_logs.length - 1);
    _trimOneOutOfRetentionLog();

    if (!_filterCallback(newEntry)) {
      // Only add the log to filtered logs if it matches the filter.
      return;
    }
    _filteredLogs.add(_FilteredLogEntry(newEntry));

    // TODO(danchevalier): Calculate the new offset here

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
    return entry.height ??= LoggingTableRow.calculateRowHeight(
      entry.log,
      _tableWidth,
    );
  }

  /// Get the height of a filtered Log at [index].
  double getFilteredLogHeight(int index) {
    final filteredLog = _filteredLogs.elementAt(index);
    final cachedHeight = filteredLog.logEntry.height;
    if (cachedHeight != null) return cachedHeight;

    return filteredLog.logEntry.height ??= LoggingTableRow.calculateRowHeight(
      filteredLog.logEntry.log,
      _tableWidth,
    );
  }

  Future<bool> _preFetchRowHeights() async {
    final didComplete = await _worker.doWork(_logs.length);
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    _recalculateOffsets();
    return didComplete;
  }

  /// The toggle filters available for the Logging screen.
  @override
  List<ToggleFilter<LogDataV2>> createToggleFilters() => [
        if (serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
            true) ...[
          ToggleFilter<LogDataV2>(
            name: 'Hide verbose Flutter framework logs (initialization, frame '
                'times, image sizes)',
            includeCallback: (log) => !_verboseFlutterFrameworkLogKinds
                .any((kind) => kind.caseInsensitiveEquals(log.kind)),
            enabledByDefault: true,
          ),
          ToggleFilter<LogDataV2>(
            name: 'Hide verbose Flutter service logs (service extension state '
                'changes)',
            includeCallback: (log) => !_verboseFlutterServiceLogKinds
                .any((kind) => kind.caseInsensitiveEquals(log.kind)),
            enabledByDefault: true,
          ),
        ],
        ToggleFilter<LogDataV2>(
          name: 'Hide garbage collection logs',
          includeCallback: (log) => !log.kind.caseInsensitiveEquals(_gcLogKind),
          enabledByDefault: true,
        ),
      ];
}

/// A class for holding a [LogDataV2] and its current estimated [height].
///
/// The [log] and its [height] have similar lifecycles, so it is helpful to keep
/// them tied together.
class _LogEntry {
  _LogEntry(this.log);
  final LogDataV2 log;

  /// The current calculated height [log].
  double? height;
}

/// A class for holding a [logEntry] and its [offset] from the top of a list of
/// filtered entries.
///
/// The [logEntry] and its [offset] have similar lifecycles, so it is helpful to keep
/// them tied together.
class _FilteredLogEntry {
  _FilteredLogEntry(this.logEntry);

  final _LogEntry logEntry;

  /// The offset of this log entry in a view.
  double? offset;
}
