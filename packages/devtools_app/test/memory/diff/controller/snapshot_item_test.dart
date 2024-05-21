// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/screens/memory/panes/diff/controller/snapshot_item.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  for (final encode in [true, false]) {
    test(
      '$SnapshotDataItem serializes and deserializes correctly',
      () async {
        final item = SnapshotDataItem(
          defaultName: 'defaultName',
          displayNumber: 5,
          nameOverride: 'nameOverride',
        );
        await item.loadHeap(HeapGraphLoaderGoldens());

        Map<String, dynamic> json = item.toJson();

        if (encode) {
          final encoded = jsonEncode(json, toEncodable: (e) => toEncodable);
          json = jsonDecode(encoded);
        }

        expect(
          json.keys.toSet(),
          equals(Json.values.map((e) => e.name).toSet()),
        );
        final fromJson = SnapshotDataItem.fromJson(json);

        expect(fromJson.defaultName, item.defaultName);
        expect(fromJson.displayNumber, item.displayNumber);
        expect(fromJson.nameOverride, item.nameOverride);

        await fromJson.process;

        expect(
          fromJson.heap!.graph.objects.length,
          item.heap!.graph.objects.length,
        );

        expect(fromJson.heap!.created, item.heap!.created);
      },
    );
  }
}
