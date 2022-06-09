import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';
import 'model.dart';
import 'path_finder.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<IdentityHashCode>>;

Future<String> getSerializedTask(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;
  final task = LeakAnalysisTask.fromSnapshot(graph, reports);
  return jsonEncode(task.toJson());
}

Future<void> setRetainingPaths(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;

  final task = LeakAnalysisTask.fromSnapshot(graph, reports);

  final pathAnalyzer = _PathAnalyzer(task.objects);
  for (var report in reports) {
    report.retainingPath = pathAnalyzer.getPath(report.theIdentityHashCode);
  }
}

class _PathAnalyzer {
  _PathAnalyzer(this.objects) {
    _buildStrictures();
  }

  late Retainers _retainers;
  // All objects by hashcode.
  late Map<int, HeapObject> objects;

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

  String getPath(IdentityHashCode code) {
    final path = findPathFromRoot(_retainers, code);
    if (path == null) throw 'All retainers looped.';
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
      // '_WidgetTicker',
    };

    return toSkip.contains(klass);
  }
}
