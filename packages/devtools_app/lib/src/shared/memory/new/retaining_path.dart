// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../class_name.dart';
import 'heap_data.dart';

/// A retaining path from the root to an object.
///
/// This class is used to represent the shortest retaining path from the root to an object.
///
/// Equal paths are not stored twice in memory.
///
/// The retaining path is represented as a list of classes, ignoring information
/// about concrete instances and fields.
/// To get more detailed information about the retaining path,
/// use [`leak_tracker/formattedRetainingPath`](https://github.com/dart-lang/leak_tracker/blob/f5620600a5ce1c44f65ddaa02001e200b096e14c/pkgs/leak_tracker/lib/src/leak_tracking/helpers.dart#L58).
class RetainingPath {
  RetainingPath._(this.path);

  final List<HeapClassName> path;

  static final _instances = <RetainingPath>{};

  static RetainingPath forObject(
    HeapData heap,
    Uint32List shortestRetainers,
    int objectId,
  ) {
    final retainers = heap.shortestRetainers;
    if (retainers == null) {
      throw StateError(
        'Shortest retainers should be calculated to obtain retaining path.',
      );
    }

    final growableClasses = <HeapClassName>[];

    while (retainers[objectId] > 0) {
      objectId = retainers[objectId];
      final classId = heap.graph.objects[objectId].classId;
      final className =
          HeapClassName.fromHeapSnapshotClass(heap.graph.classes[classId]);
      growableClasses.add(className);
    }

    final newTempInstance = RetainingPath._(growableClasses);

    return RetainingPath._([]);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is HeapClassName && other.fullName == fullName;
  }

  @override
  late final hashCode = fullName.hashCode;
}
