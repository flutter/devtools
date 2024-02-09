// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

class HeapData {
  HeapData._({
    required this.graph,
    required this.shortestRetainers,
    required this.retainedSizes,
  });

  final HeapSnapshotGraph graph;
  final Uint32List? shortestRetainers;
  final Uint32List? retainedSizes;
}

HeapData calculateHeapData(
  HeapSnapshotGraph graph, {
  bool retainers = true,
  bool retainedSizes = true,
}) {
  final Uint32List shortestRetainers = Uint32List(graph.objects.length);

  return HeapData._(
      graph: graph, shortestRetainers: shortestRetainers, retainedSizes: null);
}
