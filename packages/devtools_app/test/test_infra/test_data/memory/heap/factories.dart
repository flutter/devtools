// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/memory/classes.dart';
import 'package:devtools_app/src/shared/memory/heap_data.dart';

import 'heap_graph_mock.dart';

Future<HeapData> testHeapData() async => await HeapData.calculate(
      HeapSnapshotGraphMock(),
      DateTime.now(),
      rootIndex: HeapSnapshotGraphMock.rootIndex,
    );

SingleClassData testClassData({deleted, persistedBefore}) {}
