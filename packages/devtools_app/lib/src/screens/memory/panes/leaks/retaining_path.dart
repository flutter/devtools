import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<HeapSnapshotObject>>;

Future<void> setRetainingPaths(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;
  final pathAnalyzer = _PathAnalyzer(graph);

  for (var report in reports) {
    report.retainingPath = pathAnalyzer.getPath(report.theIdentityHashCode);
  }
}

class _PathAnalyzer {
  _PathAnalyzer(this.graph) {
    _buildStrictures();
  }

  final HeapSnapshotGraph graph;
  late Retainers retainers;
  late Map<int, HeapSnapshotObject> byCode;

  void _buildStrictures() {
    retainers = {};
    byCode = {};

    for (var object in graph.objects) {
      if (_shouldSkip(object)) continue;

      byCode[object.identityHashCode] = object;

      for (var r in object.references) {
        final reference = graph.objects[r];
        if (_shouldSkip(reference)) continue;
        if (reference.identityHashCode == object.identityHashCode) continue;

        if (!retainers.containsKey(reference.identityHashCode))
          retainers[reference.identityHashCode] = {};
        retainers[reference.identityHashCode]!.add(object);
      }
    }
  }

  String getPath(IdentityHashCode code) {
    final path = [byCode[code]!];
    IdentityHashCode current = code;

    while (retainers[current]?.isNotEmpty == true) {
      if (path.length > 1000) throw 'Too large path.';

      if (retainers[current]!.length > 1) {
        final list =
            retainers[current]!.toList().map((e) => _name(e)).join(', ');
        print(list);
      }

      path.insert(0, retainers[current]!.first);
      current = path.first.identityHashCode;

      assert(
        current != code,
        'loop found',
      );
      assert(!_shouldSkip(path.first));
    }

    final result = path.map((e) => _name(e)).join('/');
    return '/$result/';
  }

  static String _name(HeapSnapshotObject object) {
    return '${object.identityHashCode}-${object.klass.name}';
  }

  static bool _shouldSkip(HeapSnapshotObject object) {
    if (object.identityHashCode == 0) return true;

    const toSkip = {
      '_WeakReferenceImpl',
      'FinalizerEntry',
      'DiagnosticsProperty',
      '_ElementDiagnosticableTreeNode',
      '_InspectorReferenceData',
    };
    if (toSkip.contains(object.klass.name)) return true;

    return false;
  }
}
