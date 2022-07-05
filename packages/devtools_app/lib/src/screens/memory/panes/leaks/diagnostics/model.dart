import 'package:vm_service/vm_service.dart';

import '../instrumentation/model.dart';

/// Result of analysis of [notGCed] memory leaks.
class NotGCedAnalyzed {
  NotGCedAnalyzed(this.byCulprits, this.withoutPath, this.total);

  /// Not GCed objects withretaining path to the root, by culprits.
  final Map<LeakReport, List<LeakReport>> byCulprits;

  /// Not GCed objects without retaining path to the root.
  final List<LeakReport> withoutPath;

  /// Total number of leaks.
  final int total;
}

/// Input for analyses of notGCed leaks.
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

/// Contains information from [HeapSnapshotGraph], necessary to analyze
/// memory leaks, plus serialization.
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

  HeapPath? _retainingPath(IdentityHashCode code) {
    assert(isSpanningTreeBuilt);
    var i = _byCode[code]!;
    if (objects[i].retainer == null) return null;

    final result = <int>[];

    while (i >= 0) {
      result.insert(0, i);
      i = objects[i].retainer!;
    }

    return result;
  }

  /// Retaining path for the object in string format.
  String? shortPath(IdentityHashCode code) {
    final path = _retainingPath(code);
    if (path == null) return null;
    return '/${path.map((i) => objects[i].shortName).join('/')}/';
  }

  /// Retaining path for the object as an array of the retaining objects.
  List<String>? detailedPath(IdentityHashCode code) {
    final path = _retainingPath(code);
    if (path == null) return null;
    return path.map((i) => objects[i].name).toList();
  }
}

/// Result of invocation of [inentityHashCode()].
typedef IdentityHashCode = int;

/// Sequence of ids of objects in the heap.
typedef HeapPath = List<int>;

/// Contains information from [HeapSnapshotObject], necessary to analyze
/// memory leaks, plus serialization.
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

  /// No serialization is needed for the field because the field is used after
  /// the object transfer.
  /// [null] - retainer is unknown, -1 - the object is root.
  int? retainer;

  Map<String, dynamic> toJson() => {
        'code': code,
        'references': references,
        'klass': klass,
        'library': library.toString(),
      };

  String get name => '$library/$shortName';
  String get shortName => '$klass-$code';
}
