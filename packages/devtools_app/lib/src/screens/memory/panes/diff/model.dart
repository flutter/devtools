// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

class Snapshot {
  Snapshot(this.name, this.graph);

  final String name;
  Future<HeapSnapshotGraph> graph;
}
