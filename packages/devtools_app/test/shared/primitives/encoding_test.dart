// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/shared/primitives/encoding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/test_data/memory/heap/heap_data.dart';

void main() {
  test('$HeapSnapshotGraphEncodeDecode and $ByteDataEncodeDecode', () async {
    final (graph, _) = await HeapGraphLoaderGoldens().load();
    final encodeDecode = HeapSnapshotGraphEncodeDecode.instance;

    final encoded = jsonEncode(graph, toEncodable: toEncodable);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded.classes.length, graph.classes.length);
    expect(decoded.objects.length, graph.objects.length);
  });

  test('$DateTimeEncodeDecode', () {
    final date = DateTime.now();
    final encodeDecode = DateTimeEncodeDecode.instance;

    final encoded = encodeDecode.toEncodable(date);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded, date);
  });

  test('$IsolateRef', () {
    final isolateRef = IsolateRef(
      id: '1',
      name: 'name',
      number: '2',
    );
    final encodeDecode = IsolateRefEncodeDecode.instance;

    final encoded = encodeDecode.toEncodable(isolateRef);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded.id, isolateRef.id);
    expect(decoded.name, isolateRef.name);
    expect(decoded.number, isolateRef.number);
  });

  test('$ClassRef', () {
    final classRef = ClassRef(
      id: '1',
      name: 'name',
      library: LibraryRef(
        id: '2',
        name: 'name',
      ),
    );
    final encodeDecode = ClassRefEncodeDecode.instance;

    final encoded = encodeDecode.toEncodable(classRef);
    final decoded = encodeDecode.decode(encoded);

    expect(decoded.id, classRef.id);
    expect(decoded.name, classRef.name);
    expect(decoded.library!.id, classRef.library!.id);
    expect(decoded.library!.name, classRef.library!.name);
  });
}
