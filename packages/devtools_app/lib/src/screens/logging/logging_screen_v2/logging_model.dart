// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
class LoggingTableModel extends ChangeNotifier {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(
      callback: (index) => getFilteredLogHeight(
        index,
      ),
      progressCallback: (progress) => _cacheLoadProgress.value = progress,
    );
  }

  final _logs = <LogDataV2>[];
  final _filteredLogs = <LogDataV2>[];
  final _selectedLogs = <int>{};

  final cachedHeights = <int, double>{};
  final cachedOffets = <int, double>{};
  late final InterruptableChunkWorker _worker;

  /// Represents the state of reloading the height caches.
  ///
  /// When null, then the cache is not loading.
  /// When double, then the value is represents how much progress has been made.
  ValueListenable<double?> get cacheLoadProgress => _cacheLoadProgress;
  final _cacheLoadProgress = ValueNotifier<double?>(null);

  @override
  void dispose() {
    super.dispose();
    _cacheLoadProgress.dispose();
  }

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
  LogDataV2 filteredLogAt(int index) => _filteredLogs[index];

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
    getFilteredLogHeight(
      _logs.length - 1,
    );
    notifyListeners();
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
      _logs[index],
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
