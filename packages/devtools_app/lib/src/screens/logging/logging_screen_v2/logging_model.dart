import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logging_controller_v2.dart';
import 'logging_table_row.dart';

class LoggingTableModel extends ChangeNotifier {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(callback: getRowHeight);
  }

  final List<LogDataV2> _logs = [];
  final List<LogDataV2> _filteredLogs = [];
  final Set<int> _selectedLogs = <int>{};

  final Map<int, double> cachedHeights = {};
  final Map<int, double> cachedOffets = {};

  late final InterruptableChunkWorker _worker;
  final Debouncer _debouncer = Debouncer(milliseconds: 250);

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
    _cacheLoadProgress.value = 0.0;
    final didComplete = await _worker.doWork(
      _logs.length,
      (progress) => _cacheLoadProgress.value = progress,
    );
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    return didComplete;
  }
}

class InterruptableChunkWorker {
  InterruptableChunkWorker({
    int chunkSize = 50,
    required this.callback,
  }) : _chunkSize = chunkSize;

  final int _chunkSize;
  int _workId = 0;
  void Function(int) callback;

  final _sw = Stopwatch();

  Future<bool> doWork(
    int length,
    void Function(double progress) progressCallback,
  ) async {
    final completer = Completer<bool>();
    final localWorkId = ++_workId;
    final sw = Stopwatch();

    Function(int i)? doChunkWork;

    // Found out what the problem is, when scrolled to the bottom the single asks for height have to wait until the others are called. So we would need to implement a priority queue.
    doChunkWork = (i) {
      // print(
      //   'CHUNKWORK(globalId: $_workId, localId:$localWorkId), length: $length, i: $i)',
      // );
      if (i >= length) {
        sw.stop();
        return completer.complete(true);
      }

      // If our localWorkId is no longer active, then do not continue working
      if (localWorkId != _workId) return completer.complete(false);

      _sw.reset();
      _sw.start();

      final J = min(length, i + _chunkSize);
      int j = i;
      for (; j < J; j++) {
        callback(j);
      }
      _sw.stop();

      progressCallback(j / length);
      Future.delayed(const Duration(), () {
        doChunkWork!.call(i + _chunkSize);
      });
    };
    sw.start();
    doChunkWork(0);
    return completer.future;
  }
}

class Debouncer {
  Debouncer({required this.milliseconds});
  final int milliseconds;
  Timer? _timer;

  void run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
