import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import 'retaining_path.dart';

class HeapObject {
  HeapObject({required this.references, required this.klass});

  factory HeapObject.fromJson(Map<String, dynamic> json) => HeapObject(
        references: json['references'],
        klass: json['klass'],
      );

  final List<IdentityHashCode> references;
  final String klass;

  Map<String, dynamic> toJson() => {
        'references': references,
        'klass': klass,
      };
}

class LeakAnalysisTask {
  factory LeakAnalysisTask.fromJson(Map<String, dynamic> json) =>
      LeakAnalysisTask._(
        objects: json['objects'],
        reports: json['reports'],
      );

  LeakAnalysisTask._({required this.objects, required this.reports});

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

  Map<String, dynamic> toJson() => {
        'objects': objects,
        'reports': reports,
      };
}
