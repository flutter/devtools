import 'package:flutter/material.dart';
import 'package:memory_tools/model.dart';

import '../../memory_controller.dart';
import 'graph_analyzer.dart';
import 'model.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<IdentityHashCode>>;

Future<RetainingPathExtractionTask> getTask(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;
  return RetainingPathExtractionTask.fromSnapshot(graph, reports);
}

void setRetainingPathsOrRetainers(
  RetainingPathExtractionTask task,
) {
  final pathExtractor = RetainingPathExtractor(task.objects);
  for (var report in task.reports) {
    if (report.token == '681924862') print('!!!!! 681924862 updated');
    report.retainingPath = null;
    report.retainers = null;
    report.retainingPath = pathExtractor.getPath(report.theIdentityHashCode);
    if (report.retainingPath == null) {
      report.retainers =
          pathExtractor.getRetainers(report.theIdentityHashCode, 5);
      assert(report.retainers != null);
    }
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

  String? getPath(IdentityHashCode code) {
    final path = findPathFromRoot(_retainers, code);
    if (path == null) return null;
    final result = path.map((i) => _name(i, objects[i]!)).join('/');
    return '/$result/';
  }

  static String _name(IdentityHashCode code, HeapObject object) =>
      '$code-${object.klass}';

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

  // Assuming all paths are infinite.
  Map<String, dynamic> getRetainers(IdentityHashCode code, int levels) {
    if (levels <= 0) return {};

    final result = <String, dynamic>{};
    for (var r in _retainers[code]!) {
      result[_name(r, objects[r]!)] = getRetainers(r, levels - 1);
    }
    return result;
  }
}
