// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import 'class_name.dart';
import 'simple_items.dart';

/// Names for json fields.
class _JsonFields {
  static const String code = 'code';
  static const String references = 'references';
  static const String klass = 'klass';
  static const String library = 'library';
  static const String shallowSize = 'shallowSize';
}

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
