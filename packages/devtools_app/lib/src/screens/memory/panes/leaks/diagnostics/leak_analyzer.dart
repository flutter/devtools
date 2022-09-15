// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/heap/model.dart';
import '../../../shared/heap/spanning_tree.dart';
import '../instrumentation/model.dart';
import 'model.dart';

/// Analyzes notGCed leaks and returns result of the analysis.
NotGCedAnalyzed analyseNotGCed(NotGCedAnalyzerTask task) {
  analyzeHeapAndSetRetainingPaths(task.heap, task.reports);

  final leaksWithPath = task.reports.where((r) => r.retainingPath != null);
  final leaksWithoutPath = task.reports.where((r) => r.retainingPath == null);
  final leaksByCulprits = findCulprits(leaksWithPath);

  for (var report in leaksByCulprits.keys) {
    report.detailedPath = task.heap.detailedPath(report.code);
  }

  return NotGCedAnalyzed(
    leaksByCulprits: leaksByCulprits,
    leaksWithoutRetainingPath: leaksWithoutPath.toList(),
    totalLeaks: task.reports.length,
  );
}

/// Sets [retainingPath] to each [notGCedLeaks].
void analyzeHeapAndSetRetainingPaths(
  AdaptedHeap heap,
  List<LeakReport> notGCedLeaks,
) {
  if (!heap.isSpanningTreeBuilt) buildSpanningTree(heap);

  for (var l in notGCedLeaks) {
    l.retainingPath = heap.shortPath(l.code);
  }
}

/// Sets [detailedPath] to each leak.
void setDetailedPaths(AdaptedHeap heap, List<LeakReport> notGCedLeaks) {
  assert(heap.isSpanningTreeBuilt);

  for (var l in notGCedLeaks) {
    l.detailedPath = heap.detailedPath(l.code);
  }
}

/// Out of list of notGCed objects, identifies ones that hold others from
/// garbage collection (i.e. culprits).
///
/// Returns map, where the keys are the identified culprits and values are their
/// victims.
@visibleForTesting
Map<LeakReport, List<LeakReport>> findCulprits(
  Iterable<LeakReport> notGCed,
) {
  final leaksByPath = Map<String, LeakReport>.fromIterable(
    notGCed,
    key: (r) => r.retainingPath,
    value: (r) => r,
  );

  final result = <LeakReport, List<LeakReport>>{};
  String previousPath = '--- not a path ---';
  late LeakReport previousReport;
  for (var path in leaksByPath.keys.toList()..sort()) {
    final report = leaksByPath[path]!;
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
