// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file_selector/file_selector.dart';
import 'package:vm_service/vm_service.dart';

import '../../../screens/memory/shared/primitives/memory_timeline.dart';
import '../../../screens/memory/shared/primitives/memory_utils.dart';

abstract class HeapGraphGetter {
  Future<HeapSnapshotGraph?> get();
}

class HeapGraphGetterRuntime extends HeapGraphGetter {
  HeapGraphGetterRuntime(this._timeline);

  final MemoryTimeline? _timeline;

  @override
  Future<HeapSnapshotGraph?> get() async {
    final snapshot = await snapshotMemoryInSelectedIsolate();
    _timeline?.addSnapshotEvent();
    return snapshot;
  }
}

class HeapGraphGetterFromFile implements HeapGraphGetter {
  HeapGraphGetterFromFile(this._file);

  final XFile _file;

  @override
  Future<HeapSnapshotGraph?> get() async {
    final bytes = await _file.readAsBytes();
    final data = bytes.buffer.asByteData();
    return HeapSnapshotGraph.fromChunks([data]);
  }
}
