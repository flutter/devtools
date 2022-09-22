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
  AdaptedHeapData(
    this.objects, {
    this.rootIndex = _defaultRootIndex,
    DateTime? created,
  })  : assert(objects.isNotEmpty),
        assert(objects.length > rootIndex) {
    this.created = created ?? DateTime.now();
  }

  factory AdaptedHeapData.fromJson(Map<String, dynamic> json) {
    final createdJson = json[_JsonFields.created];

    return AdaptedHeapData(
      (json[_JsonFields.objects] as List<dynamic>)
          .map((e) => AdaptedHeapObject.fromJson(e))
          .toList(),
      created: createdJson == null ? null : DateTime.parse(createdJson),
      rootIndex: json[_JsonFields.rootIndex] ?? _defaultRootIndex,
    );
  }

  factory AdaptedHeapData.fromHeapSnapshot(HeapSnapshotGraph graph) =>
      AdaptedHeapData(
        graph.objects
            .map((e) => AdaptedHeapObject.fromHeapSnapshotObject(e))
            .toList(),
      );

  /// Default value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
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
        _JsonFields.created: created.toIso8601String(),
      };

  int? objectIndexByIdentityHashCode(IdentityHashCode code) =>
      _objectsByCode[code];

  HeapPath? retainingPath(int objectIndex) {
    assert(isSpanningTreeBuilt);

    if (objects[objectIndex].retainer == null) return null;

    final result = <AdaptedHeapObject>[];

    while (objectIndex >= 0) {
      final object = objects[objectIndex];
      result.add(object);
      objectIndex = object.retainer!;
    }

    return HeapPath(result.reversed.toList(growable: false));
  }
}

/// Result of invocation of [identityHashCode].
typedef IdentityHashCode = int;

/// Sequence of ids of objects in the heap.
///
/// TODO(polina-c): maybe we do not need to store path by objects.
/// It can be that only classes are interesting, and we can save some
/// performance on this object. It will become clear when the leak tracking
/// feature stabilizes.
class HeapPath {
  HeapPath(this.objects);

  final List<AdaptedHeapObject> objects;

  /// Retaining path for the object in string format.
  String? shortPath() => '/${objects.map((o) => o.shortName).join('/')}/';

  /// Retaining path for the object as an array of the retaining objects.
  List<String>? detailedPath() =>
      objects.map((o) => o.name).toList(growable: false);
}

/// Heap path represented by classes only, without object details.
class ClassOnlyHeapPath {
  ClassOnlyHeapPath(HeapPath heapPath)
      : classes =
            heapPath.objects.map((o) => o.heapClass).toList(growable: false);
  final List<HeapClass> classes;

  String asShortString() => classes.map((e) => e.className).join('/');
  String asLongString() => classes.map((e) => e.fullName).join('\n');

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ClassOnlyHeapPath && other.asLongString() == asLongString();
  }

  @override
  int get hashCode => asLongString().hashCode;
}

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

/// This class is needed to make the snapshot taking operation mockable.
class SnapshotTaker {
  Future<AdaptedHeapData?> take() async {
    final snapshot = await snapshotMemory();
    if (snapshot == null) return null;
    return AdaptedHeapData.fromHeapSnapshot(snapshot);
  }
}

@immutable
class HeapClass {
  const HeapClass({required this.className, required this.library});

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
