// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:leak_tracker/devtools_integration.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../shared/memory/adapted_heap_data.dart';

/// Result of analysis of [notGCed] memory leaks.
class NotGCedAnalyzed {
  NotGCedAnalyzed({
    required this.leaksByCulprits,
    required this.leaksWithoutRetainingPath,
    required this.totalLeaks,
  });

  /// Not GCed objects with retaining path to the root, by culprits.
  final Map<LeakReport, List<LeakReport>> leaksByCulprits;

  /// Not GCed objects without retaining path to the root.
  final List<LeakReport> leaksWithoutRetainingPath;

  final int totalLeaks;
}

/// Input for analyses of notGCed leaks.
class NotGCedAnalyzerTask {
  NotGCedAnalyzerTask({
    required this.heap,
    required this.reports,
  });

  static Future<NotGCedAnalyzerTask> fromSnapshot(
    HeapSnapshotGraph graph,
    List<LeakReport> reports,
  ) async {
    return NotGCedAnalyzerTask(
      heap: await AdaptedHeapData.fromHeapSnapshot(graph),
      reports: reports,
    );
  }

  final AdaptedHeapData heap;
  final List<LeakReport> reports;
}
