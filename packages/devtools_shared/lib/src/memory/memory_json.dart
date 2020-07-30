// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'heap_sample.dart';

class MemoryJson {
  /// Given a JSON string representing an array of HeapSample, decode to a
  /// List of HeapSample.
  MemoryJson.decode({
    String argJsonString,
    Map<String, dynamic> argDecodedMap,
  }) {
    final Map<String, dynamic> decodedMap =
        argDecodedMap == null ? jsonDecode(argJsonString) : argDecodedMap;
    final Map<String, dynamic> samplesPayload =
        decodedMap['$_jsonPayloadField'];

    final payloadVersion = samplesPayload['$_jsonVersionField'];
    final payloadDevToolsScreen = samplesPayload['$_jsonDevToolsScreenField'];

    if (payloadVersion != HeapSample.version) {
      // TODO(terry): Convert Payload TBD - only one version today.
      // TODO(terry): Notify user the file is being converted.
    }

    _memoryPayload = payloadDevToolsScreen == _devToolsScreenValueMemory;
    _payloadVersion = payloadVersion == HeapSample.version;

    // Any problem return (data is empty).
    if (!isMatchedVersion || !isMemoryPayload) return;

    final List dynamicList = samplesPayload['$_jsonDataField'];
    for (var index = 0; index < dynamicList.length; index++) {
      final sample = HeapSample.fromJson(dynamicList[index]);
      data.add(sample);
    }
  }

  bool _payloadVersion;

  /// Imported JSON data loaded and converted, if necessary, to the latest version.
  bool get isMatchedVersion => _payloadVersion;

  bool _memoryPayload;

  /// JSON payload field "dartDevToolsScreen" has a value of "memory" e.g.,
  ///   "dartDevToolsScreen": "memory"
  bool get isMemoryPayload => _memoryPayload;

  /// If data is empty check isMatchedVersion and isMemoryPayload to ensure the
  /// JSON file loaded is a memory file.
  final List<HeapSample> data = [];

  // TODO(terry): Expose encode/decode to Timeline too.

  /// Exported JSON payload of collected memory statistics.
  static const String _jsonPayloadField = 'samples';
  static const String _jsonDevToolsScreenField = 'dartDevToolsScreen';
  // TODO(terry): Expose Timeline.
  // const String _devToolsScreenValueTimeline = 'timeline';
  static const String _devToolsScreenValueMemory = 'memory';
  static const String _jsonVersionField = 'version';
  static const String _jsonDataField = 'data';

  /// Given a list of HeapSample, encode as a Json string.
  static String encodeHeapSamples(List<HeapSample> data) {
    final result = StringBuffer();

    // Iterate over all HeapSamples collected.
    data.map((f) {
      final encode =
          result.isNotEmpty ? encodeAnotherHeapSample(f) : encodeHeapSample(f);
      result.write(encode);
    }).toList();

    return '$header$result$trailer';
  }

  /// Structure of the memory JSON file:
  ///
  /// {
  ///   "samples": {
  ///     "version": 1,
  ///     "dartDevToolsScreen": "memory"
  ///     "data": [
  ///       Encoded Heap Sample see section below.
  ///     ]
  ///   }
  /// }

  /// Header portion (memoryJsonHeader) e.g.,
  /// =======================================
  /// {
  ///   "samples": {
  ///     "version": 1,
  ///     "dartDevToolsScreen": "memory"
  ///     "data": [
  ///
  /// Encoded Heap Sample memoryEncodeHeapSample/memoryEncodeAnotherHeapSample e.g.,
  /// ==============================================================================
  ///     {
  ///       "timestamp":1581540967479,
  ///       "rss":211419136,
  ///       "capacity":50956576,
  ///       "used":41384952,
  ///       "external":166176,
  ///       "gc":false,
  ///       "adb_memoryInfo":{
  ///         "Realtime":450147758,
  ///         "Java Heap":7416,
  ///         "Native Heap":41712,
  ///         "Code":12644,
  ///         "Stack":52,
  ///         "Graphics":0,
  ///         "Private Other":94420,
  ///         "System":6178,
  ///         "Total":162422
  ///       }
  ///     },
  ///
  /// Trailer portion (memoryJsonTrailer) e.g.,
  /// =========================================
  ///     ]
  ///   }
  /// }

  /// Header portion:
  static String get header => '{"$_jsonPayloadField": {'
      '"$_jsonVersionField": ${HeapSample.version}, '
      '"$_jsonDevToolsScreenField": "$_devToolsScreenValueMemory", '
      '"$_jsonDataField": [\n';

  /// Trailer portion:
  static String get trailer => '\n]\n}}';

  /// Encoded Heap Sample
  static String encodeHeapSample(HeapSample sample) => jsonEncode(sample);

  /// More than one Encoded Heap Sample, add a comma and the Encoded Heap Sample.
  static String encodeAnotherHeapSample(HeapSample sample) =>
      ',\n${jsonEncode(sample)}';
}
