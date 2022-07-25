// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../instrumentation/model.dart';

/// Result of analysis of [notGCed] memory leaks.
class NotGCedAnalyzed {
  NotGCedAnalyzed({
    required this.leaksByCulprits,
    required this.leaksWithoutRetainingPath,
    required this.totalLeaks,
  });

  /// Not GCed objects with retaining path to the root, by culprits.
  final Map<LeakReport, List<LeakReport>> leaksByCulprits;

  /// Not GCed objects without retaining path to the root.
  final List<LeakReport> leaksWithoutRetainingPath;

  final int totalLeaks;
}

/// Names for json fields.
class _JsonFields {
  static const String reports = 'reports';
  static const String heap = 'heap';
  static const String objects = 'objects';
  static const String code = 'code';
  static const String references = 'references';
  static const String klass = 'klass';
  static const String library = 'library';
}

/// Input for analyses of notGCed leaks.
class NotGCedAnalyzerTask {
  NotGCedAnalyzerTask({
    required this.heap,
    required this.reports,
  });

  factory NotGCedAnalyzerTask.fromJson(Map<String, dynamic> json) =>
      NotGCedAnalyzerTask(
        reports: (json[_JsonFields.reports] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => LeakReport.fromJson(e))
            .toList(),
        heap: AdaptedHeap.fromJson(json[_JsonFields.heap]),
      );

  NotGCedAnalyzerTask.fromSnapshot(HeapSnapshotGraph graph, this.reports)
      : heap = AdaptedHeap.fromHeapSnapshot(graph);

  final AdaptedHeap heap;
  final List<LeakReport> reports;

  Map<String, dynamic> toJson() => {
        _JsonFields.reports: reports.map((e) => e.toJson()).toList(),
        _JsonFields.heap: heap.toJson(),
      };
}

/// Contains information from [HeapSnapshotGraph], necessary to analyze
/// memory leaks, plus serialization.
class AdaptedHeap {
  AdaptedHeap(this.objects);

  factory AdaptedHeap.fromJson(Map<String, dynamic> json) => AdaptedHeap(
        (json[_JsonFields.objects] as List<dynamic>)
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

  /// Heap objects by identityHashCode.
  late final Map<IdentityHashCode, int> _objectsByCode = Map.fromIterable(
    Iterable.generate(objects.length),
    key: (i) => objects[i].code,
    value: (i) => i,
  );

  Map<String, dynamic> toJson() => {
        _JsonFields.objects: objects.map((e) => e.toJson()).toList(),
      };

  HeapPath? _retainingPath(IdentityHashCode code) {
    assert(isSpanningTreeBuilt);
    var i = _objectsByCode[code]!;
    if (objects[i].retainer == null) return null;

    final result = <int>[];

    while (i >= 0) {
      result.add(i);
      i = objects[i].retainer!;
    }

    return result.reversed.toList(growable: false);
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
        code: json[_JsonFields.code],
        references: (json[_JsonFields.references] as List<dynamic>).cast<int>(),
        klass: json[_JsonFields.klass],
        library: json[_JsonFields.library],
      );

  final List<int> references;
  final String klass;
  final String library;
  final IdentityHashCode code;

  /// No serialization is needed for the field because the field is used after
  /// the object transfer.
  /// Special values: [null] - retainer is unknown, -1 - the object is root.
  int? retainer;

  Map<String, dynamic> toJson() => {
        _JsonFields.code: code,
        _JsonFields.references: references,
        _JsonFields.klass: klass,
        _JsonFields.library: library.toString(),
      };

  String get name => '$library/$shortName';
  String get shortName => '$klass-$code';
}
