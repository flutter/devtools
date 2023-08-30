// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import 'class_name.dart';
import 'simple_items.dart';

// Wrappers for fiels are needed to separate memory footprint for
// AdaptedHeapObject, in heap snapshots, taken for DevTools,
// for analysis and optimization.

class _OutRefs {
  _OutRefs(this.refs);

  final Set<int> refs;
}

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required outRefs,
    required heapClass,
    required this.shallowSize,
  })  : _outRefs = _OutRefs(outRefs),
        _heapClass = heapClass;

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

  _OutRefs _outRefs;
  Set<int> get outRefs => _outRefs.refs;

  Set<int>? _inRefs = {};
  Set<int> get inRefs => _inRefs!;
  set inRefs(Set<int> value) => _inRefs = value;

  HeapClassName? _heapClass;
  HeapClassName get heapClass => _heapClass!;
  set heapClass(HeapClassName value) => _heapClass = value;

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

  String get shortName => '${heapClass.className}-$code';

  String get name => '${heapClass.library}/$shortName';
}
