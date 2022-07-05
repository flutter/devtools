import 'package:flutter/material.dart';
import '../instrumentation/model.dart';
import 'heap_analyser.dart';
import 'model.dart';

NotGCedAnalyzed analyseNotGCed(NotGCedAnalyzerTask task) {
  analyzeHeapAndSetRetainingPaths(task.heap, task.reports);

  final withPath = task.reports.where((r) => r.retainingPath != null);
  final withoutPath = task.reports.where((r) => r.retainingPath == null);
  final byCulprits = findCulprits(withPath);

  for (var report in byCulprits.keys) {
    report.detailedPath = task.heap.detailedPath(report.code);
  }

  return NotGCedAnalyzed(
    byCulprits,
    withoutPath.toList(),
    task.reports.length,
  );
}

@visibleForTesting
Map<LeakReport, List<LeakReport>> findCulprits(
  Iterable<LeakReport> notGCed,
) {
  final byPath = Map<String, LeakReport>.fromIterable(
    notGCed,
    key: (r) => r.retainingPath,
    value: (r) => r,
  );

  final result = <LeakReport, List<LeakReport>>{};
  String previousPath = '--- not existing path ---';
  late LeakReport previousReport;
  for (var path in byPath.keys.toList()..sort()) {
    final report = byPath[path]!;
    final isVictim = path.startsWith(previousPath);

    if (isVictim) {
      result[previousReport]!.add(report);
    } else {
      previousPath = path;
      previousReport = report;
      result[report] = [];
    }
  }
  return result;
}
