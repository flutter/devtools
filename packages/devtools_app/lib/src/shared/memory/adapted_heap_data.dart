// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'adapted_heap_object.dart';
import 'mock_heap_snapshot_graph.dart';
import 'simple_items.dart';

@immutable
class HeapObjectSelection {
  const HeapObjectSelection(this.heap, {required this.object});

  final AdaptedHeapData heap;

  /// If object is null, it exists in live app, but is not
  /// located in heap.
  final MockAdaptedHeapObject? object;

  Iterable<int>? _refs(RefDirection direction) {
    switch (direction) {
      case RefDirection.inbound:
        return object?.inRefs;
      case RefDirection.outbound:
        return object?.outRefs;
    }
  }

  List<HeapObjectSelection> references(RefDirection direction) =>
      (_refs(direction) ?? [])
          .map((i) => HeapObjectSelection(heap, object: heap.objects[i]))
          .toList();

  int? countOfReferences(RefDirection? direction) =>
      direction == null ? null : _refs(direction)?.length;

  HeapObjectSelection withoutObject() {
    if (object == null) return this;
    return HeapObjectSelection(heap, object: null);
  }
}

typedef HeapDataCallback = AdaptedHeapData Function();

/// Contains information from [HeapSnapshotGraph],
/// needed for memory screen.
class AdaptedHeapData {
  @visibleForTesting
  AdaptedHeapData(
    this.objects, {
    this.rootIndex = _defaultRootIndex,
    DateTime? created,
    HeapSnapshotGraph? graph,
  })  : assert(objects.isNotEmpty),
        assert(objects.length > rootIndex),
        graph = graph ?? MockHeapSnapshotGraph() {
    this.created = created ?? DateTime.now();
  }

  static Future<AdaptedHeapData> fromHeapSnapshot(
    HeapSnapshotGraph graph,
  ) async {
    final objects = <MockAdaptedHeapObject>[];
    for (final i in Iterable<int>.generate(graph.objects.length)) {
      if (_uiReleaser.step()) await _uiReleaser.releaseUi();
      final object =
          MockAdaptedHeapObject.fromHeapSnapshotObject(graph.objects[i], i);
      objects.add(object);
    }

    return AdaptedHeapData(objects, graph: graph);
  }

  static Future<AdaptedHeapData> fromBytes(
    Uint8List bytes,
  ) {
    final data = bytes.buffer.asByteData();
    final graph = HeapSnapshotGraph.fromChunks([data]);
    return fromHeapSnapshot(graph);
  }

  static final _uiReleaser = UiReleaser();

  final HeapSnapshotGraph graph;

  /// Default value for rootIndex is taken from the doc:
  /// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
  static const int _defaultRootIndex = 1;

  final int rootIndex;

  MockAdaptedHeapObject get root => objects[rootIndex];

  final List<MockAdaptedHeapObject> objects;

  /// Total size of all objects in the heap.
  ///
  /// Should be set externally.
  late int totalDartSize;

  bool allFieldsCalculated = false;

  late DateTime created;

  String snapshotName = '';

  /// Heap objects by `identityHashCode`.
  late final _objectsByCode = <IdentityHashCode, int?>{
    for (var i in Iterable<int>.generate(objects.length)) objects[i].code: i,
  };

  int? objectIndexByIdentityHashCode(IdentityHashCode code) =>
      _objectsByCode[code];

  HeapPath? retainingPath(int objectIndex) {
    assert(allFieldsCalculated);

    if (objects[objectIndex].retainer == null) return null;

    final result = <MockAdaptedHeapObject>[];

    while (objectIndex >= 0) {
      final object = objects[objectIndex];
      result.add(object);
      objectIndex = object.retainer!;
    }

    return HeapPath(result.reversed.toList(growable: false));
  }

  late final totalReachableSize = () {
    if (!allFieldsCalculated) throw StateError('Spanning tree should be built');
    return objects[rootIndex].retainedSize!;
  }();
}

/// Sequence of ids of objects in the heap.
class HeapPath {
  HeapPath(this.objects);
  final List<MockAdaptedHeapObject> objects;
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
