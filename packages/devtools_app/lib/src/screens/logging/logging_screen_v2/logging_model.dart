import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import 'logging_controller_v2.dart';
import 'logging_table_row.dart';

class LoggingTableModel extends ChangeNotifier {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(
      callback: getRowHeight,
      progressCallback: (progress) => _cacheLoadProgress.value = progress,
    );
  }

  final List<LogDataV2> _logs = [];
  final List<LogDataV2> _filteredLogs = [];
  final Set<int> _selectedLogs = <int>{};

  final Map<int, double> cachedHeights = {};
  final Map<int, double> cachedOffets = {};

  late final InterruptableChunkWorker _worker;

  /// Represents the state of reloading the height caches.
  ///
  /// When null, then the cache is not loading.
  /// When double, then the value is represents how much progress has been made.
  ValueListenable<double?> get cacheLoadProgress => _cacheLoadProgress;
  final _cacheLoadProgress = ValueNotifier<double?>(null);

  set tableWidth(double width) {
    _tableWidth = width;
    cachedHeights.clear();
    cachedOffets.clear();
    unawaited(_preFetchRowHeights());
  }

  LogDataV2 getLog(int index) => _logs[index];

  double _tableWidth = 0.0;

  int get logCount => _logs.length;
  int get filteredLogCount => _filteredLogs.length;
  int get selectedLogCount => _selectedLogs.length;

  void add(LogDataV2 log) {
    _logs.add(log);
    _filteredLogs.add(log);
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _filteredLogs.clear();
    notifyListeners();
  }

  double getRowOffset(int index) {
    throw 'Implement this when needed';
  }

  double getRowHeight(int index) {
    final cachedHeight = cachedHeights[index];
    if (cachedHeight != null) return cachedHeight;
    final newHeight = LoggingTableRow.calculateRowHeight(
      _logs[index],
      _tableWidth,
    );
    cachedHeights[index] = newHeight;
    return newHeight;
  }

  Future<bool> _preFetchRowHeights() async {
    final didComplete = await _worker.doWork(
      _logs.length,
    );
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    return didComplete;
  }
}
