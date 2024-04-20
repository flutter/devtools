// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class GCStats {
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
