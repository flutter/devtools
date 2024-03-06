// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'adapted_heap_object.dart';
import 'class_name.dart';
import 'mock_heap_snapshot_graph.dart';
import 'new/heap_data.dart';
import 'simple_items.dart';

@immutable
class HeapObject {
  const HeapObject(this.heap, {required this.object});

  final HeapData heap;

  /// If object is null, it exists in live app, but is not
  /// located in heap.
  final int? object;

  Iterable<int>? _refs(RefDirection direction) {
    final theObject = object;
    if (theObject == null) return null;

    switch (direction) {
      case RefDirection.inbound:
        return heap.graph.objects[theObject].referrers;
      case RefDirection.outbound:
        return heap.graph.objects[theObject].references;
    }
  }

  List<HeapObject> references(RefDirection direction) =>
      (_refs(direction) ?? []).map((i) => HeapObject(heap, object: i)).toList();

  int? countOfReferences(RefDirection? direction) =>
      direction == null ? null : _refs(direction)?.length;

  HeapObject withoutObject() {
    if (object == null) return this;
    return HeapObject(heap, object: null);
  }

  HeapClassName? get className {
    final theObjectId = object;
    if (theObjectId == null) return null;
    final theClass =
        heap.graph.classes[heap.graph.objects[theObjectId].classId];
    return HeapClassName.fromHeapSnapshotClass(theClass);
  }

  int? get code =>
      object == null ? null : heap.graph.objects[object!].identityHashCode;

  int? get retainedSize => object == null ? null : heap.retainedSizes?[object!];
}

typedef HeapDataCallback = HeapData Function();

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
