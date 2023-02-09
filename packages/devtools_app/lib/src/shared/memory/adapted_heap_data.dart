// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'class_name.dart';
import 'simple_items.dart';

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

class HeapObjectSelection {
  HeapObjectSelection(this.heap, {required this.object});

  final AdaptedHeapData heap;
  final AdaptedHeapObject? object;

  Iterable<int> _refs(RefDirection direction) {
    final theObject = object!;
    switch (direction) {
      case RefDirection.inbound:
        return theObject.inRefs;
      case RefDirection.outbound:
        return theObject.outRefs;
    }
  }

  List<HeapObjectSelection> references(RefDirection direction) =>
      _refs(direction)
          .map((i) => HeapObjectSelection(heap, object: heap.objects[i]))
          .toList();

  int? countOfReferences(RefDirection? direction) =>
      direction == null ? null : _refs(direction).length;
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
      (json[_JsonFields.objects] as List<Object?>)
          .mapIndexed(
            (i, e) => AdaptedHeapObject.fromJson(e as Map<String, Object?>, i),
          )
          .toList(),
      created: createdJson == null ? null : DateTime.parse(createdJson),
      rootIndex: json[_JsonFields.rootIndex] ?? _defaultRootIndex,
    );
  }

  static final _uiReleaser = UiReleaser();

  static Future<AdaptedHeapData> fromHeapSnapshot(
    HeapSnapshotGraph graph,
  ) async {
    final objects = <AdaptedHeapObject>[];
    for (final i in Iterable.generate(graph.objects.length)) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
      final object =
          AdaptedHeapObject.fromHeapSnapshotObject(graph.objects[i], i);
      objects.add(object);
    }

    return AdaptedHeapData(objects);
  }

  /// Default value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int _defaultRootIndex = 1;

  final int rootIndex;

  AdaptedHeapObject get root => objects[rootIndex];

  final List<AdaptedHeapObject> objects;

  bool allFieldsCalculated = false;

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
    assert(allFieldsCalculated);

    if (objects[objectIndex].retainer == null) return null;

    final result = <AdaptedHeapObject>[];

    while (objectIndex >= 0) {
      final object = objects[objectIndex];
      result.add(object);
      objectIndex = object.retainer!;
    }

    return HeapPath(result.reversed.toList(growable: false));
  }

  late final totalSize = () {
    if (!allFieldsCalculated) throw StateError('Spanning tree should be built');
    return objects[rootIndex].retainedSize!;
  }();
}

/// Result of invocation of [identityHashCode].
typedef IdentityHashCode = int;

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required this.outRefs,
    required this.heapClass,
    required this.shallowSize,
  });

  factory AdaptedHeapObject.fromHeapSnapshotObject(
    HeapSnapshotObject object,
    int index,
  ) {
    return AdaptedHeapObject(
      code: object.identityHashCode,
      outRefs: Set.of(object.references.where((i) => i != index)),
      heapClass: HeapClassName.fromHeapSnapshotClass(object.klass),
      shallowSize: object.shallowSize,
    );
  }

  factory AdaptedHeapObject.fromJson(Map<String, Object?> json, int index) =>
      AdaptedHeapObject(
        code: json[_JsonFields.code] as int,
        outRefs: (json[_JsonFields.references] as List<Object?>)
            .cast<int>()
            .where((i) => i != index)
            .toSet(),
        heapClass: HeapClassName(
          className: json[_JsonFields.klass] as String,
          library: json[_JsonFields.library],
        ),
        shallowSize: (json[_JsonFields.shallowSize] ?? 0) as int,
      );

  final Set<int> outRefs;
  final Set<int> inRefs = {};
  final HeapClassName heapClass;
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
        _JsonFields.references: outRefs.toList(),
        _JsonFields.klass: heapClass.className,
        _JsonFields.library: heapClass.library,
        _JsonFields.shallowSize: shallowSize,
      };

  String get shortName => '${heapClass.className}-$code';

  String get name => '${heapClass.library}/$shortName';
}

/// Sequence of ids of objects in the heap.
class HeapPath {
  HeapPath(this.objects);

  final List<AdaptedHeapObject> objects;

  late final bool isRetainedBySameClass = () {
    if (objects.length < 2) return false;

    final theClass = objects.last.heapClass;

    return objects
        .take(objects.length - 1)
        .any((object) => object.heapClass == theClass);
  }();

  /// Retaining path for the object in string format.
  String shortPath() => '/${objects.map((o) => o.shortName).join('/')}/';

  /// Retaining path for the object as an array of the retaining objects.
  List<String> detailedPath() =>
      objects.map((o) => o.name).toList(growable: false);
}
