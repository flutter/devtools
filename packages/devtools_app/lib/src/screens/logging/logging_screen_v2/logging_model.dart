// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/globals.dart';
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
class LoggingTableModel extends ChangeNotifier with DisposerMixin {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(
      callback: (index) => getFilteredLogHeight(
        index,
      ),
      progressCallback: (progress) => _cacheLoadProgress.value = progress,
    );

    _retentionLimit = preferences.logging.retentionLimit.value;

    addAutoDisposeListener(
      preferences.logging.retentionLimit,
      _onRetentionLimitUpdate,
    );
  }

  final _logs = ListQueue<LogDataV2>();
  final _filteredLogs = ListQueue<LogDataV2>();
  final _selectedLogs = ListQueue<LogDataV2>();
  late int _retentionLimit;

  final cachedHeights = <int, double>{};
  final cachedOffets = <int, double>{};
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

    notifyListeners();
  }

  @override
  void dispose() {
    _cacheLoadProgress.dispose();
    _worker.dispose();
    super.dispose();
  }

  double get tableWidth => _tableWidth;

  /// Update the width of the table.
  ///
  /// If different from the last width, this will flush all of the calculated heights, and recalculate their heights
  /// in the background.
  set tableWidth(double width) {
    if (width != _tableWidth) {
      _tableWidth = width;
      cachedHeights.clear();
      cachedOffets.clear();
      unawaited(_preFetchRowHeights());
    }
  }

  /// Get the filtered log at [index].
  LogDataV2 filteredLogAt(int index) => _filteredLogs.elementAt(index);

  double _tableWidth = 0.0;

  /// The total number of logs being held by the [LoggingTableModel].
  int get logCount => _logs.length;

  /// The number of filtered logs.
  int get filteredLogCount => _filteredLogs.length;

  /// The number of selected logs.
  int get selectedLogCount => _selectedLogs.length;

  /// Add a log to the list of tracked logs.
  void add(LogDataV2 log) {
    // TODO(danchevalier): ensure that search and filter lists are updated here.

    _logs.add(log);
    _filteredLogs.add(log);

    _trimOneOutOfRetentionLog();

    getFilteredLogHeight(
      _logs.length - 1,
    );
    notifyListeners();
  }

  void _trimOneOutOfRetentionLog() {
    if (_logs.length > _retentionLimit) {
      if (identical(_logs.first, _filteredLogs.first)) {
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

  /// Get the height of a filtered Log at [index].
  double getFilteredLogHeight(int index) {
    final cachedHeight = cachedHeights[index];
    if (cachedHeight != null) return cachedHeight;

    return cachedHeights[index] = LoggingTableRow.calculateRowHeight(
      _logs.elementAt(index),
      _tableWidth,
    );
  }

  Future<bool> _preFetchRowHeights() async {
    final didComplete = await _worker.doWork(_logs.length);
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    return didComplete;
  }
}
