import 'package:vm_service/vm_service.dart';

import '../instrumentation/model.dart';

class NotGCedAnalyzed {
  NotGCedAnalyzed(this.byCulprits, this.withoutPath, this.total);

  final Map<LeakReport, List<LeakReport>> byCulprits;
  final List<LeakReport> withoutPath;
  final int total;
}

class NotGCedAnalyzerTask {
  NotGCedAnalyzerTask({
    required this.heap,
    required this.reports,
  });

  factory NotGCedAnalyzerTask.fromJson(Map<String, dynamic> json) =>
      NotGCedAnalyzerTask(
        reports: (json['reports'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => LeakReport.fromJson(e))
            .toList(),
        heap: AdaptedHeap.fromJson(json['heap']),
      );

  NotGCedAnalyzerTask.fromSnapshot(HeapSnapshotGraph graph, this.reports)
      : heap = AdaptedHeap.fromHeapSnapshot(graph);

  final AdaptedHeap heap;
  final List<LeakReport> reports;

  Map<String, dynamic> toJson() => {
        'reports': reports.map((e) => e.toJson()).toList(),
        'heap': heap.toJson(),
      };
}

class AdaptedHeap {
  AdaptedHeap(this.objects);

  factory AdaptedHeap.fromJson(Map<String, dynamic> json) => AdaptedHeap(
        (json['objects'] as List<dynamic>)
            .map((e) => AdaptedHeapObject.fromJson(e))
            .toList(),
      );

  factory AdaptedHeap.fromHeapSnapshot(HeapSnapshotGraph graph) => AdaptedHeap(
        graph.objects
            .map((e) => AdaptedHeapObject.fromHeapSnapshotObject(e))
            .toList(),
      );

  static const rootIndex = 1;
  final List<AdaptedHeapObject> objects;
  bool isSpanningTreeBuilt = false;

  late final Map<IdentityHashCode, int> _byCode = Map.fromIterable(
    Iterable.generate(objects.length),
    key: (i) => objects[i].code,
    value: (i) => i,
  );

  Map<String, dynamic> toJson() => {
        'objects': objects.map((e) => e.toJson()).toList(),
      };

  String toYaml() {
    final noPath = objects.where((o) => o.parent == null);
    final result = StringBuffer();

    result.writeln('with-retaining-path:');
    result.writeln('  total: ${objects.length - noPath.length}');
    result.write(_objectToYaml(objects[rootIndex], '  '));
    result.writeln('without-retaining-path:');
    result.writeln('  total: ${noPath.length}');
    result.writeln('  objects:');
    for (var o in noPath) {
      result.writeln('    ${o.name}');
    }
    return result.toString();
  }

  String _objectToYaml(AdaptedHeapObject object, String indent) {
    final firstLine = '$indent${object.name}';
    if (object.children.isEmpty) return '$firstLine\n';

    final result = StringBuffer();
    result.writeln('$firstLine:');
    for (var c in object.children) {
      final child = objects[c];
      result.write(_objectToYaml(child, '$indent  '));
    }
    return result.toString();
  }

  HeapPath? _path(IdentityHashCode code) {
    assert(isSpanningTreeBuilt);
    var i = _byCode[code]!;
    if (objects[i].parent == null) return null;

    final result = <int>[];

    while (i >= 0) {
      result.insert(0, i);
      i = objects[i].parent!;
    }

    return result;
  }

  String? shortPath(IdentityHashCode code) {
    final path = _path(code);
    if (path == null) return null;
    return '/${path.map((i) => objects[i].shortName).join('/')}/';
  }

  List<String>? detailedPath(IdentityHashCode code) {
    final path = _path(code);
    if (path == null) return null;
    return path.map((i) => objects[i].name).toList();
  }
}

typedef IdentityHashCode = int;

typedef HeapPath = List<int>;

class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required this.references,
    required this.klass,
    required this.library,
  });

  factory AdaptedHeapObject.fromHeapSnapshotObject(HeapSnapshotObject object) {
    var library = object.klass.libraryName;
    if (library.isEmpty) library = object.klass.libraryUri.toString();
    return AdaptedHeapObject(
      code: object.identityHashCode,
      references: List.from(object.references),
      klass: object.klass.name,
      library: library,
    );
  }

  factory AdaptedHeapObject.fromJson(Map<String, dynamic> json) =>
      AdaptedHeapObject(
        code: json['code'],
        references: (json['references'] as List<dynamic>).cast<int>(),
        klass: json['klass'],
        library: json['library'],
      );

  final List<int> references;
  final String klass;
  final String library;
  final IdentityHashCode code;

  // Fields for graph analysis.
  final List<int> children = [];
  // null - unknown, -1 - root.
  int? parent;

  Map<String, dynamic> toJson() => {
        'code': code,
        'references': references,
        'klass': klass,
        'library': library.toString(),
      };

  String get name => '$library/$shortName';
  String get shortName => '$klass-$code';
}
