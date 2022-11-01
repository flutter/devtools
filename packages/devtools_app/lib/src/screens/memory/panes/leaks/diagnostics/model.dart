// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../shared/heap/model.dart';
import '../instrumentation/model.dart';

/// Names for json fields.
class _JsonFields {
  static const String reports = 'reports';
  static const String heap = 'heap';
}

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

  factory NotGCedAnalyzerTask.fromJson(Map<String, dynamic> json) =>
      NotGCedAnalyzerTask(
        reports: (json[_JsonFields.reports] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => LeakReport.fromJson(e))
            .toList(),
        heap: AdaptedHeapData.fromJson(json[_JsonFields.heap]),
      );

  static Future<NotGCedAnalyzerTask> fromSnapshot(
    HeapSnapshotGraph graph,
    List<LeakReport> reports,
  ) async {
    return NotGCedAnalyzerTask(
      heap: AdaptedHeapData.fromHeapSnapshot(graph),
      reports: reports,
    );
  }

  final AdaptedHeapData heap;
  final List<LeakReport> reports;

  Map<String, dynamic> toJson() => {
        _JsonFields.reports: reports.map((e) => e.toJson()).toList(),
        _JsonFields.heap: heap.toJson(),
      };
}
