// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:devtools_app/src/shared/memory/heap_data.dart';
import 'package:vm_service/vm_service.dart';

Future<HeapData> testHeapData() async => await HeapData.calculate(
      HeapSnapshotGraphMock(),
      DateTime.now(),
      rootIndex: HeapSnapshotGraphMock.rootIndex,
    );

class HeapSnapshotGraphMock implements HeapSnapshotGraph {
  HeapSnapshotGraphMock();

  static const rootIndex = 0;

  @override
  int get capacity => throw UnimplementedError();

  @override
  List<HeapSnapshotClass> get classes => [];

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
  List<HeapSnapshotObject> get objects => [_HeapSnapshotObjectMock()];

  @override
  int get referenceCount => throw UnimplementedError();

  @override
  int get shallowSize => throw UnimplementedError();
}

class _HeapSnapshotObjectMock implements HeapSnapshotObject {
  _HeapSnapshotObjectMock();

  @override
  int get classId => throw UnimplementedError();

  @override
  int get identityHashCode => throw UnimplementedError();

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
