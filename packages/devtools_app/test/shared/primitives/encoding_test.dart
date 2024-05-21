// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app/src/shared/primitives/encoding.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  test('$HeapSnapshotGraphEncodeDecode', () async {
    final (graph, _) = await HeapGraphLoaderGoldens().load();
    final encodeDecode = HeapSnapshotGraphEncodeDecode.instance;

    final encoded = encodeDecode.toEncodable(graph);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded.classes.length, graph.classes.length);
  });

  test('$ByteDataEncodeDecode', () async {
    final (graph, _) = await HeapGraphLoaderGoldens().load();
    final encodeDecode = HeapSnapshotGraphEncodeDecode.instance;

    final encoded = encodeDecode.toEncodable(graph);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded.classes.length, graph.classes.length);
  });
}
