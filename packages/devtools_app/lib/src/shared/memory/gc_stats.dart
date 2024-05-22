// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

class _Json {
  static const heap = 'heap';
  static const usage = 'usage';
  static const capacity = 'capacity';
  static const collections = 'coll';
  static const averageCollectionTime = 'act';
}

class GCStats with Serializable {
  GCStats({
    required this.heap,
    required this.usage,
    required this.capacity,
    required this.collections,
    required this.averageCollectionTime,
  });

  factory GCStats.parse({
    required String heap,
    required Map<String, dynamic> json,
  }) {
    final collections = json[collectionsKey] as int;
    return GCStats(
      heap: heap,
      usage: json[usedKey],
      capacity: json[capacityKey],
      collections: collections,
      averageCollectionTime: (json[timeKey] as num) * 1000 / collections,
    );
  }

  factory GCStats.fromJson(Map<String, dynamic> json) {
    return GCStats(
      heap: json[_Json.heap] as String,
      usage: json[_Json.usage] as int,
      capacity: json[_Json.capacity] as int,
      collections: json[_Json.collections] as int,
      averageCollectionTime: json[_Json.averageCollectionTime] as double,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        _Json.heap: heap,
        _Json.usage: usage,
        _Json.capacity: capacity,
        _Json.collections: collections,
        _Json.averageCollectionTime: averageCollectionTime,
      };

  static const usedKey = 'used';
  static const capacityKey = 'capacity';
  static const collectionsKey = 'collections';
  static const timeKey = 'time';

  final String heap;
  final int usage;
  final int capacity;
  final int collections;
  final double averageCollectionTime;
}
