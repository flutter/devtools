// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../utils/serialization.dart';

/// Android ADB dumpsys meminfo data.
class AdbMemoryInfo with Serializable {
  AdbMemoryInfo(
    this.realtime,
    this.javaHeap,
    this.nativeHeap,
    this.code,
    this.stack,
    this.graphics,
    this.other,
    this.system,
    this.total,
  );

  /// All data inside of [AdbMemoryInfo] is in total bytes.
  /// When receiving ADB data from the service extension (directly from ADB)
  /// then the data is in kilobytes. See the factory constructor [fromJsonInKB].
  factory AdbMemoryInfo.fromJson(Map<String, Object?> json) => AdbMemoryInfo(
        json[realTimeKey] as int,
        json[javaHeapKey] as int,
        json[nativeHeapKey] as int,
        json[codeKey] as int,
        json[stackKey] as int,
        json[graphicsKey] as int,
        json[otherKey] as int,
        json[systemKey] as int,
        json[totalKey] as int,
      );

  /// Use when converting data received from the service extension,
  /// directly from ADB. All data received from ADB dumpsys meminfo is
  /// in kilobytes must adjust to total bytes for [AdbMemoryInfo] data.
  factory AdbMemoryInfo.fromJsonInKB(Map<String, Object?> json) {
    final realTime = json[realTimeKey] as int;
    var javaHeap = json[javaHeapKey] as int;
    var nativeHeap = json[nativeHeapKey] as int;
    var code = json[codeKey] as int;
    var stack = json[stackKey] as int;
    var graphics = json[graphicsKey] as int;
    var other = json[otherKey] as int;
    var system = json[systemKey] as int;
    var total = json[totalKey] as int;

    // Convert to total bytes.
    javaHeap *= 1024;
    nativeHeap *= 1024;
    code *= 1024;
    stack *= 1024;
    graphics *= 1024;
    other *= 1024;
    system *= 1024;
    total *= 1024;

    return AdbMemoryInfo(
      realTime,
      javaHeap,
      nativeHeap,
      code,
      stack,
      graphics,
      other,
      system,
      total,
    );
  }

  // JSON keys of data retrieved from ADB tool.

  static const String realTimeKey = 'Realtime';
  static const String javaHeapKey = 'Java Heap';
  static const String nativeHeapKey = 'Native Heap';
  static const String codeKey = 'Code';
  static const String stackKey = 'Stack';
  static const String graphicsKey = 'Graphics';
  static const String otherKey = 'Private Other';
  static const String systemKey = 'System';
  static const String totalKey = 'Total';

  @override
  Map<String, dynamic> toJson() => <String, Object?>{
        realTimeKey: realtime,
        javaHeapKey: javaHeap,
        nativeHeapKey: nativeHeap,
        codeKey: code,
        stackKey: stack,
        graphicsKey: graphics,
        otherKey: other,
        systemKey: system,
        totalKey: total,
      };

  /// Create an empty [AdbMemoryInfo], where all values are 0.
  static AdbMemoryInfo empty() => AdbMemoryInfo(0, 0, 0, 0, 0, 0, 0, 0, 0);

  /// Milliseconds since the device was booted (value zero) including deep sleep.
  ///
  /// This clock is guaranteed to be monotonic, and continues to tick even
  /// in power saving mode. The value zero is Unix Epoch UTC (Jan 1, 1970 00:00:00).
  /// This DateTime, from USA PST, would be Dec 31, 1960 16:00:00 (UTC - 8 hours).
  final int realtime;

  /// All remaining values are received from ADB in kilobytes but converted to
  /// total bytes using the [fromJsonInKB] factory.
  final int javaHeap;

  final int nativeHeap;

  final int code;

  final int stack;

  final int graphics;

  final int other;

  final int system;

  final int total;

  DateTime get realtimeDT => DateTime.fromMillisecondsSinceEpoch(realtime);

  /// Duration the device has been up since boot time.
  Duration get bootDuration => Duration(milliseconds: realtime);

  @override
  String toString() => '[AdbMemoryInfo '
      '$realTimeKey: $realtime, '
      'realtimeDT: $realtimeDT, '
      'durationBoot: $bootDuration, '
      '$javaHeapKey: $javaHeap, '
      '$nativeHeapKey: $nativeHeap, '
      '$codeKey: $code, '
      '$stackKey: $stack, '
      '$graphicsKey: $graphics, '
      '$otherKey: $other, '
      '$systemKey: $system, '
      '$totalKey: $total]';
}
