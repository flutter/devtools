// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

/// Encodes and decodes a value of type [T].
abstract class EncodeDecode<T> {
  Object toEncodable(T value);

  T decode(Object value);

  T? decodeNullable(Object? value) {
    if (value == null) return null;
    return decode(value);
  }
}

/// Encodes and decodes [HeapSnapshotGraph].
class HeapSnapshotGraphEncodeDecode extends EncodeDecode<HeapSnapshotGraph> {
  HeapSnapshotGraphEncodeDecode._();

  static final instance = HeapSnapshotGraphEncodeDecode._();

  @override
  Object toEncodable(HeapSnapshotGraph value) {
    return value.toChunks();
  }

  @override
  HeapSnapshotGraph decode(Object value) {
    if (value is HeapSnapshotGraph) return value;
    if (value is String) value = jsonDecode(value);
    value = value as List;
    final chunks =
        value.map((s) => ByteDataEncodeDecode.instance.decode(s)).toList();
    return HeapSnapshotGraph.fromChunks(chunks);
  }
}

/// Encodes and decodes [ByteData].
class ByteDataEncodeDecode extends EncodeDecode<ByteData> {
  ByteDataEncodeDecode._();

  static final instance = ByteDataEncodeDecode._();

  @override
  Object toEncodable(ByteData value) {
    final list = value.buffer.asUint8List();
    return base64Encode(list);
  }

  @override
  ByteData decode(Object value) {
    if (value is ByteData) return value;
    value = value as String;
    final list = base64Decode(value);
    return ByteData.sublistView(Uint8List.fromList(list));
  }
}

/// Encodes and decodes [DateTime].
class DateTimeEncodeDecode extends EncodeDecode<DateTime> {
  DateTimeEncodeDecode._();

  static final instance = DateTimeEncodeDecode._();

  @override
  Object toEncodable(DateTime value) {
    return value.microsecondsSinceEpoch;
  }

  @override
  DateTime decode(Object value) {
    if (value is DateTime) return value;
    return DateTime.fromMicrosecondsSinceEpoch(value as int);
  }
}

/// Encodes and decodes [IsolateRef].
class IsolateRefEncodeDecode extends EncodeDecode<IsolateRef> {
  IsolateRefEncodeDecode._();

  static final instance = IsolateRefEncodeDecode._();

  @override
  Object toEncodable(IsolateRef value) {
    return value.toJson();
  }

  @override
  IsolateRef decode(Object value) {
    if (value is IsolateRef) return value;
    final json = value as Map<String, dynamic>;
    return IsolateRef.parse(json)!;
  }
}

/// Encodes and decodes [ClassRef].
class ClassRefEncodeDecode extends EncodeDecode<ClassRef> {
  ClassRefEncodeDecode._();

  static final instance = ClassRefEncodeDecode._();

  @override
  Object toEncodable(ClassRef value) {
    return value.toJson();
  }

  @override
  ClassRef decode(Object value) {
    if (value is ClassRef) return value;
    final json = value as Map<String, dynamic>;
    return ClassRef.parse(json)!;
  }
}

/// Function to be passed to [jsonEncode] to enable encoding for more types.
Object? toEncodable(Object? value) {
  return switch (value) {
    null => null,
    final HeapSnapshotGraph value =>
      HeapSnapshotGraphEncodeDecode.instance.toEncodable(value),
    final ByteData value => ByteDataEncodeDecode.instance.toEncodable(value),
    final DateTime value => DateTimeEncodeDecode.instance.toEncodable(value),
    final IsolateRef value =>
      IsolateRefEncodeDecode.instance.toEncodable(value),
    final ClassRef value => ClassRefEncodeDecode.instance.toEncodable(value),
    final Serializable value => value.toJson(),
    _ =>
      // For some reasons the failures show different error:
      // `Converting object to an encodable object failed: Instance of 'some other type'`.
      // To see the actual type, put breakpoint here:
      throw StateError('Unsupported type: ${value.runtimeType}'),
  };
}
