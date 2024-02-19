// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../class_name.dart';

Function _listEquality = const ListEquality().equals;

typedef PathContainsClass = Map<(PathFromRoot, HeapClassName), bool>;

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
class PathFromRoot {
  PathFromRoot._(this.path)
      : hashCode = path.isEmpty ? _hashOfEmptyPath : Object.hashAll(path),
        classes = calculateSetOfClasses ? path.toSet() : const {};

  const PathFromRoot._empty()
      : path = const [],
        classes = const {},
        hashCode = _hashOfEmptyPath;

  factory PathFromRoot.forObject(
    HeapSnapshotGraph graph,
    List<int> shortestRetainers,
    int objectId,
  ) {
    var nextObjectId = shortestRetainers[objectId];
    if (nextObjectId == 0) {
      return const PathFromRoot._empty();
    }

    final path = <HeapClassName>[];

    while (shortestRetainers[nextObjectId] > 0) {
      nextObjectId = shortestRetainers[nextObjectId];
      final classId = graph.objects[nextObjectId].classId;
      final className =
          HeapClassName.fromHeapSnapshotClass(graph.classes[classId]);
      path.add(className);
    }

    return PathFromRoot.fromPath(path);
  }

  factory PathFromRoot.fromPath(List<HeapClassName> path) {
    final existingInstance = instances.lookup(PathFromRoot._(path));
    if (existingInstance != null) return existingInstance;

    final newInstance = PathFromRoot._(List.unmodifiable(path));

    instances.add(newInstance);
    return newInstance;
  }

  @visibleForTesting
  static Set<PathFromRoot> get instances => _instances ??= <PathFromRoot>{};
  static Set<PathFromRoot>? _instances;

  /// If false, the [classes] is always empty.
  static bool calculateSetOfClasses = true;

  static const _hashOfEmptyPath = 0;

  final List<HeapClassName> path;
  final Set<HeapClassName> classes;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is PathFromRoot && _listEquality(other.path, path);
  }

  @override
  final int hashCode;

  @visibleForTesting
  static void disposeSingletons() {
    _instances = null;
  }
}
