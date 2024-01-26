// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

class MockHeapSnapshotGraph implements HeapSnapshotGraph {
  @override
  int get capacity => throw UnimplementedError();

  @override
  List<HeapSnapshotClass> get classes => throw UnimplementedError();

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
  List<HeapSnapshotObject> get objects => throw UnimplementedError();

  @override
  int get referenceCount => throw UnimplementedError();

  @override
  int get shallowSize => throw UnimplementedError();
}
