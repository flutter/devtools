// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:devtools_app/src/shared/memory/simple_items.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

typedef RefsByIndex = Map<int, List<int>>;
typedef ClassByIndex = Map<int, HeapClassName>;

class HeapSnapshotGraphFake extends Fake implements HeapSnapshotGraph {
  HeapSnapshotGraphFake();

  @override
  final List<HeapSnapshotClass> classes = [
    _HeapSnapshotClassFake(),
    _HeapSnapshotClassFake.weak(),
  ];

  @override
  final List<HeapSnapshotObject> objects = [
    _HeapSnapshotObjectFake(), // Sentinel
    _HeapSnapshotObjectFake(), // Root
  ];

  /// Adds object and returns index of the added object.
  int add(int hashCode) {
    objects.add(_HeapSnapshotObjectFake(identityHashCode: hashCode));
    return objects.length - 1;
  }

  /// Resets objects.
  ///
  /// Cleans all objects.
  /// Creates sentinel at index 0 and sets one byte objects itemized in [refsByIndex] with given references.
  ///
  /// Throws if indexes are missed.
  void setObjects(
    RefsByIndex refsByIndex, {
    ClassByIndex? classes,
  }) {
    assert(!refsByIndex.containsKey(0), '0 is reserved for sentinel.');
    objects.clear();
    objects.add(_HeapSnapshotObjectFake()); // Sentinel
    addObjects(refsByIndex, classes: classes);
  }

  /// Adds instances of specific class names.
  ///
  /// The objects are one byte size, reachable directly from root.
  /// The classes has empty library name.
  void addClassInstances(Map<String, int> classToInstanceCount) {
    for (final entry in classToInstanceCount.entries) {
      final classId =
          maybeAddClass(HeapClassName(className: entry.key, library: null));
      for (var i = 0; i < entry.value; i++) {
        objects.add(
          _HeapSnapshotObjectFake(
            identityHashCode: objects.length,
            references: [],
            shallowSize: 1,
            classId: classId,
          ),
        );
        final index = objects.length - 1;
        objects[heapRootIndex].references.add(index);
      }
    }
  }

  /// Adds objects itemized in [refsByIndex] and sets [classes].
  ///
  /// Throws if indexes are missed.
  void addObjects(
    RefsByIndex refsByIndex, {
    bool weak = false,
    ClassByIndex? classes,
  }) {
    final firstNewIndex = refsByIndex.keys.min;
    assert(
      firstNewIndex == objects.length,
      'Objects should be added at the end.',
    );

    final newLength = refsByIndex.keys.max + 1;
    for (var i = firstNewIndex; i < newLength; i++) {
      if (!refsByIndex.containsKey(i)) throw 'Index $i is missed.';

      int? classId = maybeAddClass(classes?[i]);
      classId ??= weak ? _weakClassId : _defaultClassId;

      objects.add(
        _HeapSnapshotObjectFake(
          identityHashCode: i,
          references: refsByIndex[i] ?? [],
          shallowSize: 1,
          classId: classId,
        ),
      );
      assert(objects.length - 1 == i);
    }
  }

  int? maybeAddClass(HeapClassName? className) {
    if (className == null) return null;
    final index = classes.indexWhere(
      (c) => HeapClassName.fromHeapSnapshotClass(c) == className,
    );
    if (index >= 0) return index;

    classes.add(
      _HeapSnapshotClassFake(
        name: className.className,
        libraryName: className.library,
        classId: classes.length,
      ),
    );
    return classes.length - 1;
  }
}

class _HeapSnapshotClassFake extends Fake implements HeapSnapshotClass {
  _HeapSnapshotClassFake({
    this.name = 'DefaultClass',
    this.libraryName = 'package:default/default.dart',
    this.classId = _defaultClassId,
  });

  _HeapSnapshotClassFake.weak()
      : name = '_WeakProperty',
        libraryName = 'dart:core',
        classId = _weakClassId {
    assert(HeapClassName.fromHeapSnapshotClass(this).isWeak);
  }

  @override
  final String name;

  @override
  final String libraryName;

  @override
  final int classId;

  @override
  late final libraryUri = Uri.parse('');
}

const int _defaultClassId = 0;
const int _weakClassId = 1;

class _HeapSnapshotObjectFake extends Fake implements HeapSnapshotObject {
  _HeapSnapshotObjectFake({
    this.identityHashCode = 0,
    List<int>? references,
    this.shallowSize = 0,
    int? classId,
  }) : classId = classId ?? _defaultClassId {
    this.references = Uint32List.fromList(references ?? []);
  }

  @override
  final int classId;

  @override
  final int identityHashCode;

  @override
  late Uint32List references;

  @override
  int shallowSize;
}
