import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<HeapSnapshotObject>>;

Retainers buildRetainers(HeapSnapshotGraph graph) {
  final Retainers result = {};

  for (var object in graph.objects) {
    if (_shouldSkip(object)) continue;
    for (var r in object.references) {
      final reference = graph.objects[r];
      if (_shouldSkip(reference)) continue;
      if (reference.identityHashCode == object.identityHashCode) continue;

      if (!result.containsKey(reference.identityHashCode))
        result[reference.identityHashCode] = {};
      result[reference.identityHashCode]!.add(object);
    }
  }
  return result;
}

Future<void> setRetainingPaths(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;
  final retainers = buildRetainers(graph);

  for (var report in reports) {
    report.retainingPath = _getPath(retainers, report.theIdentityHashCode);
  }
}

String _getPath(Retainers retainers, IdentityHashCode code) {
  final path = <HeapSnapshotObject>[];
  IdentityHashCode current = code;

  while (retainers[current]?.isNotEmpty == true) {
    if (path.length > 1000) throw 'Too large path.';

    // var list = retainers[current]!.toList().map((e) => _name(e)).join(',');

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

String _name(HeapSnapshotObject object) {
  return '${object.identityHashCode}-${object.klass.name}';
}

bool _shouldSkip(HeapSnapshotObject object) {
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
