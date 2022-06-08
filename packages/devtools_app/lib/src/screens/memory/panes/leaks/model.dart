import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import 'retaining_path.dart';

class HeapObject {
  HeapObject({required this.references, required this.klass});

  final List<IdentityHashCode> references;
  final String klass;
}

class LeakAnalysisTask {
  LeakAnalysisTask.fromSnapshot(HeapSnapshotGraph graph, this.reports) {
    objects = Map.fromIterable(
      graph.objects,
      key: (o) => o.identityHashCode,
      value: (o) => HeapObject(
          references: _extractReferences(o, graph), klass: o.klass.name),
    );
  }

  static List<IdentityHashCode> _extractReferences(
          HeapSnapshotObject object, HeapSnapshotGraph graph) =>
      object.references.map((e) => graph.objects[e].identityHashCode).toList();

  late Map<IdentityHashCode, HeapObject> objects;
  final Iterable<ObjectReport> reports;
}
