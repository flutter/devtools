// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:vm_service/vm_service.dart';

typedef RefsByIndex = Map<int, List<int>>;

class HeapSnapshotGraphMock implements HeapSnapshotGraph {
  HeapSnapshotGraphMock();

  @override
  int get capacity => throw UnimplementedError();

  @override
  final List<HeapSnapshotClass> classes = [
    _HeapSnapshotClassMock(),
    _HeapSnapshotClassMock.weak(),
  ];

  @override
  List<HeapSnapshotExternalProperty> get externalProperties =>
      throw UnimplementedError();

  @override
  int get externalSize => throw UnimplementedError();

  @override
  int get flags => throw UnimplementedError();

  @override
  String get name => throw UnimplementedError();

  @override
  final List<HeapSnapshotObject> objects = [
    _HeapSnapshotObjectMock(), // Sentinel
    _HeapSnapshotObjectMock(), // Root
  ];

  @override
  int get referenceCount => throw UnimplementedError();

  @override
  int get shallowSize => throw UnimplementedError();

  @override
  List<ByteData> toChunks() => throw UnimplementedError();

  /// Adds object and returns index of the added object.
  int add(int hashCode) {
    objects.add(_HeapSnapshotObjectMock(identityHashCode: hashCode));
    return objects.length - 1;
  }

  /// Resets objects.
  ///
  /// Cleans all objects.
  /// Creates sentinel at index 0 and sets one byte objects itemized in [refsByIndex] with given references.
  ///
  /// Throws if indexes are missed.
  void setObjects(RefsByIndex refsByIndex) {
    assert(!refsByIndex.containsKey(0), '0 is reserved for sentinel.');
    objects.clear();
    objects.add(_HeapSnapshotObjectMock()); // Sentinel
    final newLength = refsByIndex.keys.max + 1;
    for (var i = 1; i < newLength; i++) {
      if (!refsByIndex.containsKey(i)) throw 'Index $i is missed.';
      objects.add(
        _HeapSnapshotObjectMock(
          identityHashCode: i,
          references: refsByIndex[i] ?? [],
          shallowSize: 1,
        ),
      );
      assert(objects.length - 1 == i);
    }
  }

  /// Sets weak objects itemized in [refsByIndex].
  ///
  /// Throws if indexes are missed.
  void addWeakObjects(RefsByIndex refsByIndex) {
    objects.add(_HeapSnapshotObjectMock.weak());
  }
}

class _HeapSnapshotClassMock implements HeapSnapshotClass {
  _HeapSnapshotClassMock({
    this.name = 'DefaultClass',
    this.libraryName = 'package:default/default.dart',
    this.classId = _defaultClassId,
  });

  _HeapSnapshotClassMock.weak()
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
  List<HeapSnapshotField> get fields => throw UnimplementedError();

  @override
  late final libraryUri = Uri.parse('');
}

const int _defaultClassId = 0;
const int _weakClassId = 1;

class _HeapSnapshotObjectMock implements HeapSnapshotObject {
  _HeapSnapshotObjectMock({
    this.identityHashCode = 0,
    List<int>? references,
    this.shallowSize = 0,
    this.classId = _defaultClassId,
  }) {
    this.references = Uint32List.fromList(references ?? []);
  }

  /// One byte weak object.
  _HeapSnapshotObjectMock.weak() : this(classId: _weakClassId, shallowSize: 1);

  @override
  final int classId;

  @override
  final int identityHashCode;

  @override
  HeapSnapshotClass get klass => throw UnimplementedError();

  @override
  late Uint32List references;

  @override
  Uint32List get referrers => throw UnimplementedError();

  @override
  int shallowSize;

  @override
  Iterable<HeapSnapshotObject> get successors => throw UnimplementedError();

  @override
  // ignore: avoid-dynamic, inherited type
  dynamic get data => throw UnimplementedError();
}
