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

final _sentinelObject = FakeSnapshotObjectFake();

const _defaultClassId = 0;
const _weakClassId = 1;
const _library = 'package:myLib/myLib.dart';

class FakeHeapSnapshotGraph extends Fake implements HeapSnapshotGraph {
  FakeHeapSnapshotGraph();

  @override
  final List<HeapSnapshotClass> classes = [
    _FakeHeapSnapshotClass(),
    _FakeHeapSnapshotClass.weak(),
  ];

  @override
  final List<FakeSnapshotObjectFake> objects = [
    _sentinelObject,
    FakeSnapshotObjectFake(shallowSize: 1), // root
  ];

  /// Adds object and returns index of the added object.
  int add([int? hashCode]) {
    objects.add(
      FakeSnapshotObjectFake(identityHashCode: hashCode ?? objects.length),
    );
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
    objects.add(_sentinelObject);
    addObjects(refsByIndex, classes: classes);
  }

  /// Adds an object with specific path to root.
  ///
  /// Returns index of the object.
  int addChain(List<String> path) {
    var referrer = heapRootIndex;
    for (var name in path) {
      final classId =
          maybeAddClass(HeapClassName(library: _library, className: name));
      final index = add();
      objects[index].classId = classId!;
      objects[referrer]._references.add(index);
      referrer = index;
    }
    return referrer;
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
          FakeSnapshotObjectFake(
            identityHashCode: objects.length,
            references: [],
            shallowSize: 1,
            classId: classId,
          ),
        );
        final index = objects.length - 1;
        objects[heapRootIndex].addReference(index);
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
        FakeSnapshotObjectFake(
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
      _FakeHeapSnapshotClass(
        name: className.className,
        libraryName: className.library,
        classId: classes.length,
      ),
    );
    return classes.length - 1;
  }
}

class _FakeHeapSnapshotClass extends Fake implements HeapSnapshotClass {
  _FakeHeapSnapshotClass({
    this.name = 'DefaultClass',
    this.libraryName = _library,
    this.classId = _defaultClassId,
  });

  _FakeHeapSnapshotClass.weak()
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

class FakeSnapshotObjectFake extends Fake implements HeapSnapshotObject {
  FakeSnapshotObjectFake({
    this.identityHashCode = 0,
    List<int>? references,
    this.shallowSize = 0,
    int? classId,
  })  : classId = classId ?? _defaultClassId,
        _references = references ?? [];

  @override
  int classId;

  @override
  final int identityHashCode;

  @override
  Uint32List get references => Uint32List.fromList(_references);
  final List<int> _references;

  @override
  int shallowSize;

  void addReference(int i) {
    _references.add(i);
  }
}
