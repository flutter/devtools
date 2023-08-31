// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import 'class_name.dart';
import 'simple_items.dart';

// TODO: remove wrappers.

class _OutRefs {
  _OutRefs(this.refs);

  final Set<int> refs;
}

class _InRefs {
  _InRefs(this.refs);

  final Set<int> refs;
}

class _ClassName {
  _ClassName(this.name);

  final HeapClassName name;
}

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class AdaptedHeapObject {
  AdaptedHeapObject({
    required this.code,
    required Set<int> outRefs,
    required HeapClassName heapClass,
    required this.shallowSize,
  })  : _outRefs = _OutRefs(outRefs),
        _heapClass = _ClassName(heapClass);

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

  final _OutRefs _outRefs;
  Set<int> get outRefs => _outRefs.refs;

  final _InRefs _inRefs = _InRefs({});
  Set<int> get inRefs => _inRefs.refs;

  final _ClassName _heapClass;
  HeapClassName get heapClass => _heapClass.name;

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
