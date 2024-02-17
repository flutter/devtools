// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../class_name.dart';
import 'heap_data.dart';

Function _listEquality = const ListEquality().equals;

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

  factory RetainingPath.forObject(
    HeapData heap,
    Uint32List shortestRetainers,
    int objectId,
  ) {
    final path = <HeapClassName>[];

    while (shortestRetainers[objectId] > 0) {
      objectId = shortestRetainers[objectId];
      final classId = heap.graph.objects[objectId].classId;
      final className =
          HeapClassName.fromHeapSnapshotClass(heap.graph.classes[classId]);
      path.add(className);
    }

    return RetainingPath.fromPath(path);
  }

  factory RetainingPath.fromPath(List<HeapClassName> path) {
    final existingInstance = _instances.lookup(RetainingPath._(path));
    if (existingInstance != null) return existingInstance;

    final newInstance = RetainingPath._(List.unmodifiable(path));
    return newInstance;
  }

  final List<HeapClassName> path;

  static final _instances = <RetainingPath>{};

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RetainingPath && _listEquality(other.path, path);
  }

  @override
  late final hashCode = path.hashCode;
}
