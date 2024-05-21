// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

Object? toEncodable(Object? value) {
  if (value is HeapSnapshotGraph) {
    return _graphToEncodable(value);
  }
  if (value is ByteData) {
    return _byteDataToEncodable(value);
  }
  if (value is DateTime) {
    return _dateTimeToEncodable(value);
  }
  return value;
}

Object? _byteDataToEncodable(ByteData byteData) {
  final list = byteData.buffer.asUint8List();
  return base64Encode(list);
}

ByteData _decodeByteData(String value) {
  final list = base64Decode(value);
  return ByteData.sublistView(Uint8List.fromList(list));
}

Object? _graphToEncodable(HeapSnapshotGraph graph) {
  return graph.toChunks();
}

HeapSnapshotGraph? decodeHeapSnapshotGraph(Object? value) {
  if (value == null) return null;
  if (value is HeapSnapshotGraph) return value;

  value = (value as List).cast<String>();
  final chunks = value.map((s) => _decodeByteData(s)).toList();
  return HeapSnapshotGraph.fromChunks(chunks);
}

Object? _dateTimeToEncodable(DateTime dateTime) {
  return dateTime.microsecondsSinceEpoch;
}

DateTime decodeDateTime(int microsecondsSinceEpoch) {
  return DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch);
}
