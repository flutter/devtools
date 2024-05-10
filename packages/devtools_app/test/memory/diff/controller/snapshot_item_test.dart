// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/snapshot_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  test(
    '$SnapshotDataItem serializes and deserializes correctly',
    () async {
      final item = SnapshotDataItem(
        defaultName: 'defaultName',
        displayNumber: 1,
        nameOverride: 'nameOverride',
      );
      await item.loadHeap(HeapGraphLoaderGoldens());

      final json = item.toJson();
      final fromJson = SnapshotDataItem.fromJson(json);

      expect(fromJson.defaultName, item.defaultName);
      expect(fromJson.displayNumber, item.displayNumber);
      expect(fromJson.nameOverride, item.nameOverride);

      await fromJson.process;

      expect(
        fromJson.heap!.graph.objects.length,
        item.heap!.graph.objects.length,
      );
    },
  );
}
