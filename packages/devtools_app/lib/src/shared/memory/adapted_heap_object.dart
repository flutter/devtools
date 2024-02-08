// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import 'class_name.dart';
import 'simple_items.dart';

/// Contains information from [HeapSnapshotObject] needed for
/// memory analysis on memory screen.
class MockAdaptedHeapObject {
  MockAdaptedHeapObject({
    required this.code,
    required this.outRefs,
    required this.heapClass,
    required this.shallowSize,
  });

  factory MockAdaptedHeapObject.fromHeapSnapshotObject(
    HeapSnapshotObject object,
    int index,
  ) {
    return MockAdaptedHeapObject(
      code: object.identityHashCode,
      outRefs: Set.of(object.references.where((i) => i != index)),
      heapClass: HeapClassName.fromHeapSnapshotClass(object.klass),
      shallowSize: object.shallowSize,
    );
  }

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

  String get shortName => '${heapClass.className}-$code';

  String get name => '${heapClass.library}/$shortName';
}
