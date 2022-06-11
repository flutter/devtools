import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import 'retaining_path.dart';

class HeapObject {
  HeapObject({required this.references, required this.klass});

  factory HeapObject.fromJson(Map<String, dynamic> json) => HeapObject(
        references: (json['references'] as List<dynamic>).cast<int>(),
        klass: json['klass'],
      );

  final List<IdentityHashCode> references;
  final String klass;

  Map<String, dynamic> toJson() => {
        'references': references,
        'klass': klass,
      };
}

class RetainingPathExtractionTask {
  RetainingPathExtractionTask({required this.objects, required this.reports});

  factory RetainingPathExtractionTask.fromJson(Map<String, dynamic> json) =>
      RetainingPathExtractionTask(
        objects: (json['objects'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(int.parse(key), HeapObject.fromJson(value)),
        ),
        reports: (json['reports'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => ObjectReport.fromJson(e))
            .toList(),
      );

  RetainingPathExtractionTask.fromSnapshot(
      HeapSnapshotGraph graph, this.reports) {
    objects = Map.fromIterable(
      graph.objects,
      key: (o) => o.identityHashCode,
      value: (o) => HeapObject(
        references: _extractReferences(o, graph),
        klass: o.klass.name,
      ),
    );
  }

  static List<IdentityHashCode> _extractReferences(
          HeapSnapshotObject object, HeapSnapshotGraph graph) =>
      object.references.map((e) => graph.objects[e].identityHashCode).toList();

  late Map<IdentityHashCode, HeapObject> objects;
  final List<ObjectReport> reports;

  Map<String, dynamic> toJson() => {
        'objects': objects.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value.toJson())),
        'reports': reports.map((e) => e.toJson()).toList(),
      };
}
