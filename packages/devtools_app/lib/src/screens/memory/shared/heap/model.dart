// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/memory_utils.dart';

/// Names for json fields.
class _JsonFields {
  static const String objects = 'objects';
  static const String code = 'code';
  static const String references = 'references';
  static const String klass = 'klass';
  static const String library = 'library';
  static const String shallowSize = 'shallowSize';
  static const String rootIndex = 'rootIndex';
  static const String created = 'created';
}

/// Contains information from [HeapSnapshotGraph],
/// needed for memory screen.
class AdaptedHeapData {
  /// Default value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  AdaptedHeapData(this.objects, {this.rootIndex = _defaultRootIndex})
      : assert(objects.isNotEmpty),
        assert(objects.length > rootIndex);

  factory AdaptedHeapData.fromJson(Map<String, dynamic> json) =>
      AdaptedHeapData(
        (json[_JsonFields.objects] as List<dynamic>)
            .map((e) => AdaptedHeapObject.fromJson(e))
            .toList(),
        created: json[_JsonFields.created] ?? DateTime.now(),
        rootIndex: json[_JsonFields.rootIndex] ?? _defaultRootIndex,
      );

  factory AdaptedHeapData.fromHeapSnapshot(HeapSnapshotGraph graph) =>
      AdaptedHeapData(
        graph.objects
            .map((e) => AdaptedHeapObject.fromHeapSnapshotObject(e))
            .toList(),
        created: DateTime.now(),
      );

  static const int _defaultRootIndex = 1;

  final int rootIndex;
  AdaptedHeapObject get root => objects[rootIndex];

  final List<AdaptedHeapObject> objects;

  bool isSpanningTreeBuilt = false;

  late DateTime created;

  /// Heap objects by identityHashCode.
  late final Map<IdentityHashCode, int> _objectsByCode = Map.fromIterable(
    Iterable.generate(objects.length),
    key: (i) => objects[i].code,
    value: (i) => i,
  );

  Map<String, dynamic> toJson() => {
        _JsonFields.objects: objects.map((e) => e.toJson()).toList(),
        _JsonFields.rootIndex: rootIndex,
        _JsonFields.created: created,
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

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required this.references,
    required this.heapClass,
    required this.shallowSize,
  });

  factory AdaptedHeapObject.fromHeapSnapshotObject(HeapSnapshotObject object) {
    var library = object.klass.libraryName;
    if (library.isEmpty) library = object.klass.libraryUri.toString();
    return AdaptedHeapObject(
      code: object.identityHashCode,
      references: List.from(object.references),
      heapClass: HeapClass(className: object.klass.name, library: library),
      shallowSize: object.shallowSize,
    );
  }

  factory AdaptedHeapObject.fromJson(Map<String, dynamic> json) =>
      AdaptedHeapObject(
        code: json[_JsonFields.code],
        references: (json[_JsonFields.references] as List<dynamic>).cast<int>(),
        heapClass: HeapClass(
          className: json[_JsonFields.klass],
          library: json[_JsonFields.library],
        ),
        shallowSize: json[_JsonFields.shallowSize] ?? 0,
      );

  final List<int> references;
  final HeapClass heapClass;
  final IdentityHashCode code;
  final int shallowSize;

  // No serialization is needed for the fields below, because the fields are
  // calculated after the heap deserialization.

  /// Special values: `null` - the object is not reachable,
  /// `-1` - the object is root.
  int? retainer;

  /// Total shallow size of objects, where this object is retainer, recursively,
  /// plus shallow size of this object.
  ///
  /// Null, if object is not reachable.
  int? retainedSize;

  Map<String, dynamic> toJson() => {
        _JsonFields.code: code,
        _JsonFields.references: references,
        _JsonFields.klass: heapClass.className,
        _JsonFields.library: heapClass.library,
        _JsonFields.shallowSize: shallowSize,
      };

  String get shortName => '${heapClass.className}-$code';
  String get name => '${heapClass.library}/$shortName';
}

class HeapStatsRecord {
  HeapStatsRecord(this.heapClass);

  final HeapClass heapClass;
  int shallowSize = 0;
  int retainedSize = 0;
  int instanceCount = 0;

  String get fullClassName => _fullClassName(library, className);
  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;
}

class HeapStatistics {
  HeapStatistics(this.map);

  /// Maps full class name to stats record of this class.
  final Map<String, HeapStatsRecord> map;
  late final List<HeapStatsRecord> list = map.values.toList(growable: false);
}

/// This class is needed to make snapshot taking mockable.
class SnapshotTaker {
  Future<AdaptedHeapData?> take() async {
    final snapshot = await snapshotMemory();
    if (snapshot == null) return null;
    return AdaptedHeapData.fromHeapSnapshot(snapshot);
  }
}

class HeapClass {
  HeapClass({required this.className, required this.library});

  final String className;
  final String library;

  String get fullName => library.isNotEmpty ? '$library/$className' : className;

  bool get isSentinel => className == 'Sentinel' && library.isEmpty;

  /// Detects if a class can retain an object from garbage collection.
  bool get isWeakEntry {
    // Classes that hold reference to an object without preventing
    // its collection.
    const weakHolders = {
      '_WeakProperty': 'dart.core',
      '_WeakReferenceImpl': 'dart.core',
      'FinalizerEntry': 'dart._internal',
    };

    if (!weakHolders.containsKey(className)) return false;
    if (weakHolders[className] == library) return true;

    // If a class lives in unexpected library, this can be because of
    // (1) name collision or (2) bug in this code.
    // Throwing exception in debug mode to verify option #2.
    // TODO(polina-c): create a way for users to add their weak classes
    // or detect weak references automatically, without hard coding
    // class names.
    assert(false, 'Unexpected library for $className: $library.');
    return false;
  }
}

class HeapStatistics {
  HeapStatistics(this.map);

  /// Maps full class name to stats record of this class.
  final Map<String, HeapStatsRecord> map;
  late final List<HeapStatsRecord> list = map.values.toList(growable: false);
}
