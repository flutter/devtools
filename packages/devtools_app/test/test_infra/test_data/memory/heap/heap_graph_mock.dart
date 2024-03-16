// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

typedef RefsByIndex = Map<int, List<int>>;

class HeapSnapshotGraphMock implements HeapSnapshotGraph {
  HeapSnapshotGraphMock();

  @override
  int get capacity => throw UnimplementedError();

  @override
  final List<HeapSnapshotClass> classes = [];

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

  /// Sets one byte objects with given references.
  ///
  /// Missed indexes are considered as objects without references, zero size.
  void setObjects(RefsByIndex refsByIndex) {
    assert(!refsByIndex.containsKey(0), '0 is reserved for sentinel.');
    objects.clear();
    objects.add(_HeapSnapshotObjectMock()); // Sentinel
    final newLength = refsByIndex.keys.max + 1;
    for (var i = 1; i < newLength; i++) {
      objects.add(
        _HeapSnapshotObjectMock(
          identityHashCode: i,
          references: refsByIndex[i] ?? [],
          shallowSize: refsByIndex.containsKey(i) ? 1 : 0,
        ),
      );
      assert(objects.length - 1 == i);
    }
  }
}

class _HeapSnapshotClassMock implements HeapSnapshotClass {
  _HeapSnapshotClassMock({
    this.name = '',
    this.libraryName = '',
  });

  @override
  final String name;

  @override
  final String libraryName;

  @override
  int get classId => throw UnimplementedError();

  @override
  List<HeapSnapshotField> get fields => throw UnimplementedError();

  @override
  // TODO: implement libraryUri
  Uri get libraryUri => throw UnimplementedError();
}

class _HeapSnapshotObjectMock implements HeapSnapshotObject {
  _HeapSnapshotObjectMock({
    this.identityHashCode = 0,
    List<int>? references,
    this.shallowSize = 0,
  }) {
    this.references = Uint32List.fromList(references ?? []);
  }

  @override
  int get classId => throw UnimplementedError();

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
