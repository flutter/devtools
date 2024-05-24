// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';

import '../utils/serialization.dart';
import 'adb_memory_info.dart';
import 'event_sample.dart';

@visibleForTesting
enum Json {
  rss,
  capacity,
  used,
  external,
  gc,
  adbMemoryInfo(nameOverride: 'adb_memoryInfo'),
  memoryEventInfo(nameOverride: 'memory_eventInfo'),
  rasterCache,
  timestamp;

  const Json({String? nameOverride}) : _nameOverride = nameOverride;

  final String? _nameOverride;

  String get key => _nameOverride ?? name;
}

/// DevTools Plotted and JSON persisted memory information.
class HeapSample with Serializable {
  HeapSample(
    this.timestamp,
    this.rss,
    this.capacity,
    this.used,
    this.external,
    this.isGC,
    AdbMemoryInfo? adbMemoryInfo,
    EventSample? memoryEventInfo,
    RasterCache? rasterCache,
  )   : adbMemoryInfo = adbMemoryInfo ?? AdbMemoryInfo.empty(),
        memoryEventInfo = memoryEventInfo ?? EventSample.empty(),
        rasterCache = rasterCache ?? RasterCache.empty();

  factory HeapSample.fromJson(Map<String, dynamic> json) {
    return HeapSample(
      json[Json.timestamp.key] as int,
      json[Json.rss.key] as int,
      json[Json.capacity.key] as int,
      json[Json.used.key] as int,
      json[Json.external.key] as int,
      json[Json.gc.key] as bool,
      deserialize<AdbMemoryInfo>(
        json[Json.adbMemoryInfo.key],
        AdbMemoryInfo.fromJson,
      ),
      deserialize<EventSample>(
        json[Json.memoryEventInfo.key],
        EventSample.fromJson,
      ),
      json[Json.rasterCache.key] == null
          ? null
          : deserialize<RasterCache>(
              json[Json.rasterCache.key],
              (json) => RasterCache.fromJson(json),
            ),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        Json.timestamp.key: timestamp,
        Json.rss.key: rss,
        Json.capacity.key: capacity,
        Json.used.key: used,
        Json.external.key: external,
        Json.gc.key: isGC,
        Json.adbMemoryInfo.key: adbMemoryInfo,
        Json.memoryEventInfo.key: memoryEventInfo,
        Json.rasterCache.key: rasterCache,
      };

  /// Version of HeapSample JSON payload.
  static const version = 1;

  final int timestamp;

  final int rss;

  final int capacity;

  final int used;

  final int external;

  final bool isGC;

  EventSample memoryEventInfo;

  AdbMemoryInfo adbMemoryInfo;

  RasterCache rasterCache;

  @override
  String toString() => '[HeapSample timestamp: $timestamp, '
      '${const JsonEncoder.withIndent('  ').convert(toJson())}]';
}
