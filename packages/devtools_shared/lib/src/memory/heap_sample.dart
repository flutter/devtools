// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';

import '../utils/serialization.dart';
import 'adb_memory_info.dart';
import 'event_sample.dart';

@visibleForTesting
class Json {
  static const rss = 'rss';
  static const capacity = 'capacity';
  static const used = 'used';
  static const externalMemory = 'external';
  static const gc = 'gc';
  static const adbMemoryInfo = 'adb_memoryInfo';
  static const memoryEventInfo = 'memory_eventInfo';
  static const rasterCache = 'raster_cache';
  static const timestamp = 'timestamp';

  static const all = {
    rss,
    capacity,
    used,
    externalMemory,
    gc,
    adbMemoryInfo,
    memoryEventInfo,
    rasterCache,
    timestamp,
  };
}

/// DevTools Plotted and JSON persisted memory information.
class HeapSample {
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
      json[Json.timestamp] as int,
      json[Json.rss] as int,
      json[Json.capacity] as int,
      json[Json.used] as int,
      json[Json.externalMemory] as int,
      json[Json.gc] as bool,
      deserialize<AdbMemoryInfo>(
        json[Json.adbMemoryInfo],
        AdbMemoryInfo.fromJson,
      ),
      deserialize<EventSample>(
          json[Json.memoryEventInfo], EventSample.fromJson),
      deserialize<RasterCache>(json[Json.rasterCache], RasterCache.fromJson),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        Json.timestamp: timestamp,
        Json.rss: rss,
        Json.capacity: capacity,
        Json.used: used,
        Json.externalMemory: external,
        Json.gc: isGC,
        Json.adbMemoryInfo: adbMemoryInfo,
        Json.memoryEventInfo: memoryEventInfo,
        Json.rasterCache: rasterCache,
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
