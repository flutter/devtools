// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(terry): Need the iOS version of this data.
/// Android ADB dumpsys meminfo data.
class AdbMemoryInfo {
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

  /// @param rawData (from service extension) if true then all data returned from
  /// dumpsys meminfo is in kilobytes adjust to total bytes.
  factory AdbMemoryInfo.fromJson(Map<String, dynamic> json, {rawData = false}) {
    int javaHeap = json[javaHeapKey];
    int nativeHeap = json[nativeHeapKey];
    int code = json[codeKey];
    int stack = json[stackKey];
    int graphics = json[graphicsKey];
    int other = json[otherKey];
    int system = json[systemKey];
    int total = json[totalKey];

    if (rawData) {
      javaHeap *= 1024;
      nativeHeap *= 1024;
      code *= 1024;
      stack *= 1024;
      graphics *= 1024;
      other *= 1024;
      system *= 1024;
      total *= 1024;
    }

    return AdbMemoryInfo(
      json[realTimeKey] as int,
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

  /// JSON keys of data retrieved from ADB tool.
  static const String realTimeKey = 'Realtime';
  static const String javaHeapKey = 'Java Heap';
  static const String nativeHeapKey = 'Native Heap';
  static const String codeKey = 'Code';
  static const String stackKey = 'Stack';
  static const String graphicsKey = 'Graphics';
  static const String otherKey = 'Private Other';
  static const String systemKey = 'System';
  static const String totalKey = 'Total';

  Map<String, dynamic> toJson() => <String, dynamic>{
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

  /// Create an empty AdbMemoryInfo (all values are)
  static AdbMemoryInfo empty() => AdbMemoryInfo(0, 0, 0, 0, 0, 0, 0, 0, 0);

  /// Milliseconds since the device was booted (value zero) including deep sleep.
  ///
  /// This clock is guaranteed to be monotonic, and continues to tick even
  /// in power saving mode. The value zero is Unix Epoch UTC (Jan 1, 1970 00:00:00).
  /// This DateTime, from USA PST, would be Dec 31, 1960 16:00:00 (UTC - 8 hours).
  final int realtime;

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
