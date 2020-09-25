// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'adb_memory_info.dart';
import 'event_sample.dart';

/// DevTools Plotted and JSON persisted memory information.
class HeapSample {
  HeapSample(
    this.timestamp,
    this.rss,
    this.capacity,
    this.used,
    this.external,
    this.isGC,
    this._adbMemoryInfo,
    this._memoryEventInfo,
    this._rasterCache,
  );

  factory HeapSample.fromJson(Map<String, dynamic> json) => HeapSample(
        json['timestamp'] as int,
        json['rss'] as int,
        json['capacity'] as int,
        json['used'] as int,
        json['external'] as int,
        json['gc'] as bool,
        AdbMemoryInfo.fromJson(json['adb_memoryInfo']),
        EventSample.fromJson(json['memory_eventInfo']),
        RasterCache.fromJson(json['raster_cache']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp,
        'rss': rss,
        'capacity': capacity,
        'used': used,
        'external': external,
        'gc': isGC,
        'adb_memoryInfo': adbMemoryInfo.toJson(),
        'memory_eventInfo': memoryEventInfo.toJson(),
        'raster_cache': rasterCache.toJson(),
      };

  /// Version of HeapSample JSON payload.
  static const version = 1;

  final int timestamp;

  final int rss;

  final int capacity;

  final int used;

  final int external;

  final bool isGC;

  EventSample _memoryEventInfo;

  AdbMemoryInfo _adbMemoryInfo;

  RasterCache _rasterCache;

  AdbMemoryInfo get adbMemoryInfo {
    _adbMemoryInfo ??= AdbMemoryInfo.empty();
    return _adbMemoryInfo;
  }

  EventSample get memoryEventInfo {
    _memoryEventInfo ??= EventSample.empty();
    return _memoryEventInfo;
  }

  RasterCache get rasterCache {
    _rasterCache ??= RasterCache.empty();
    return _rasterCache;
  }

  @override
  String toString() => '[HeapSample timestamp: $timestamp, '
      'rss: $rss, '
      'capacity: $capacity, '
      'used: $used, '
      'external: $external, '
      'isGC: $isGC, '
      'AdbMemoryInfo: $adbMemoryInfo, '
      'MemoryEventInfo: $memoryEventInfo, '
      'RasterCache: $rasterCache]';
}
