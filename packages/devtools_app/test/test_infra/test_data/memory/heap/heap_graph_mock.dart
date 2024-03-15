// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

class HeapSnapshotGraphMock implements HeapSnapshotGraph {
  HeapSnapshotGraphMock();

  static const rootIndex = 0;

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
  final List<HeapSnapshotObject> objects = [_HeapSnapshotObjectMock()];

  @override
  int get referenceCount => throw UnimplementedError();

  @override
  int get shallowSize => throw UnimplementedError();

  /// Adds object and returns index of the added object.
  int add(int hashCode) {
    objects.add(_HeapSnapshotObjectMock(identityHashCode: hashCode));
    return objects.length - 1;
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
  _HeapSnapshotObjectMock({this.identityHashCode = 0});

  @override
  int get classId => throw UnimplementedError();

  @override
  final int identityHashCode;

  @override
  HeapSnapshotClass get klass => throw UnimplementedError();

  @override
  Uint32List get references => Uint32List.fromList([]);

  @override
  Uint32List get referrers => throw UnimplementedError();

  @override
  int get shallowSize => 0;

  @override
  Iterable<HeapSnapshotObject> get successors => throw UnimplementedError();

  @override
  // ignore: avoid-dynamic, inherited type
  dynamic get data => throw UnimplementedError();
}
