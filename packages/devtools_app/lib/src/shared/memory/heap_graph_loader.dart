// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/memory/shared/primitives/memory_timeline.dart';
import '../../screens/memory/shared/primitives/memory_utils.dart';
import 'simple_items.dart';

abstract class HeapGraphLoader {
  const HeapGraphLoader();
  Future<(HeapSnapshotGraph, DateTime)> load();
}

/// Loads a heap snapshot for the connected application in selected isolate.
class HeapGraphLoaderRuntime extends HeapGraphLoader {
  /// If [timeline] is provided the loader will add a snapshot event to it.
  const HeapGraphLoaderRuntime(this.timeline);

  final MemoryTimeline? timeline;

  @override
  Future<(HeapSnapshotGraph, DateTime)> load() async {
    final snapshot = (await snapshotMemoryInSelectedIsolate())!;
    timeline?.addSnapshotEvent();
    return (snapshot, DateTime.now());
  }
}

class HeapGraphLoaderFile implements HeapGraphLoader {
  HeapGraphLoaderFile(this.file);

  HeapGraphLoaderFile.fromPath(String path) : file = XFile(path);

  final XFile file;

  @override
  Future<(HeapSnapshotGraph, DateTime)> load() async {
    return (
      await HeapSnapshotGraphSerialization.load(file),
      await file.lastModified(),
    );
  }
}

/// Loads a heap snapshot from `List<ByteData>` created with HeapSnapshotGraph.toChunks.
class HeapGraphLoaderFromChunks implements HeapGraphLoader {
  HeapGraphLoaderFromChunks({required this.chunks, required this.created});

  List<ByteData> chunks;

  DateTime created;

  @override
  Future<(HeapSnapshotGraph, DateTime)> load() async {
    return (HeapSnapshotGraph.fromChunks(chunks), created);
  }
}
