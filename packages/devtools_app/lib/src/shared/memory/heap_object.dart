// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'class_name.dart';
import 'heap_data.dart';
import 'simple_items.dart';

@immutable
class HeapObject {
  const HeapObject(this.heap, {required this.index});

  final HeapData heap;

  /// If object is null, it exists in live app, but is not
  /// located in heap.
  final int? index;

  Iterable<int>? _refs(RefDirection direction) {
    final theObject = index;
    if (theObject == null) return null;

    switch (direction) {
      case RefDirection.inbound:
        return heap.graph.objects[theObject].referrers;
      case RefDirection.outbound:
        return heap.graph.objects[theObject].references;
    }
  }

  List<HeapObject> references(RefDirection direction) =>
      (_refs(direction) ?? []).map((i) => HeapObject(heap, index: i)).toList();

  int? countOfReferences(RefDirection? direction) =>
      direction == null ? null : _refs(direction)?.length;

  HeapObject withoutObject() {
    if (index == null) return this;
    return HeapObject(heap, index: null);
  }

  HeapClassName? get className {
    final theIndex = index;
    if (theIndex == null) return null;
    final theClass = heap.graph.classes[heap.graph.objects[theIndex].classId];
    return HeapClassName.fromHeapSnapshotClass(theClass);
  }

  int? get code =>
      index == null ? null : heap.graph.objects[index!].identityHashCode;

  int? get retainedSize => index == null ? null : heap.retainedSizes?[index!];
}

typedef HeapDataCallback = HeapData Function();
