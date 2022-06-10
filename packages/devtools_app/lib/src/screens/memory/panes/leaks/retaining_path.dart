import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';
import 'model.dart';
import 'graph_analyzer.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<IdentityHashCode>>;

Future<RetainingPathExtractionTask> getTask(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;
  return RetainingPathExtractionTask.fromSnapshot(graph, reports);
}

void setRetainingPaths(
  RetainingPathExtractionTask task,
) {
  final pathExtractor = RetainingPathExtractor(task.objects);
  for (var report in task.reports) {
    print('!!! calculating path for ${report.theIdentityHashCode}');
    report.retainingPath = pathExtractor.getPath(report.theIdentityHashCode);
  }
}

@visibleForTesting
class RetainingPathExtractor {
  RetainingPathExtractor(this.objects) {
    _buildStrictures();
  }

  late Retainers _retainers;
  // All objects by hashcode.
  late Map<IdentityHashCode, HeapObject> objects;

  void _buildStrictures() {
    _retainers = {};

    for (var kv in objects.entries) {
      if (_shouldSkip(kv.value.klass)) continue;

      for (var r in kv.value.references) {
        final reference = objects[r]!;
        if (_shouldSkip(reference.klass)) continue;
        if (kv.key == r) continue;

        if (!_retainers.containsKey(r)) _retainers[r] = {};
        _retainers[r]!.add(kv.key);
      }
    }
  }

  Map<IdentityHashCode, HeapObject> getRoots() {
    return Map<IdentityHashCode, HeapObject>.fromIterable(
      objects.keys.where((code) => _retainers[code]?.isEmpty ?? true),
      key: (code) => code,
      value: (code) => objects[code]!,
    );
  }

  String getPath(IdentityHashCode code) {
    final path = findPathFromRoot(_retainers, code);
    if (path == null) throw 'All retainers looped for $code.';
    final result = path.map((i) => _name(i, objects[i]!.klass)).join('/');
    return '/$result/';
  }

  static String _name(IdentityHashCode code, String name) => '$code-$name';

  bool _shouldSkip(String klass) {
    const toSkip = {
      '_WeakReferenceImpl',
      'FinalizerEntry',
      // 'DiagnosticsProperty',
      // '_ElementDiagnosticableTreeNode',
      // '_InspectorReferenceData',
      // 'DebugCreator',
      //'_WidgetTicker',
    };

    return toSkip.contains(klass);
  }
}
