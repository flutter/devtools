// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

class HeapSnapshotGraphMock implements HeapSnapshotGraph {
  @override
  // TODO: implement capacity
  int get capacity => throw UnimplementedError();

  @override
  // TODO: implement classes
  List<HeapSnapshotClass> get classes => throw UnimplementedError();

  @override
  // TODO: implement externalProperties
  List<HeapSnapshotExternalProperty> get externalProperties =>
      throw UnimplementedError();

  @override
  // TODO: implement externalSize
  int get externalSize => throw UnimplementedError();

  @override
  // TODO: implement flags
  int get flags => throw UnimplementedError();

  @override
  // TODO: implement name
  String get name => throw UnimplementedError();

  @override
  // TODO: implement objects
  List<HeapSnapshotObject> get objects => throw UnimplementedError();

  @override
  // TODO: implement referenceCount
  int get referenceCount => throw UnimplementedError();

  @override
  // TODO: implement shallowSize
  int get shallowSize => throw UnimplementedError();
}
