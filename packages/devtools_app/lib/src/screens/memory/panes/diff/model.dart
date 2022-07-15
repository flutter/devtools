// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

abstract class SnapshotListItem {
  SnapshotListItem(this.name);

  final String name;
}

class SnapshotInformation extends SnapshotListItem {
  SnapshotInformation() : super('Snapshots');
}

class Snapshot extends SnapshotListItem {
  Snapshot(super.name, this.graph);

  Future<HeapSnapshotGraph> graph;
}
