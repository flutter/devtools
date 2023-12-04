// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:vm_service/vm_service.dart';

import 'heap_sample.dart';

abstract class DecodeEncode<T> {
  int get version;

  String encode(T sample);

  /// More than one Encoded entry, add a comma and the Encoded entry.
  String encodeAnother(T sample);

  T fromJson(Map<String, dynamic> json);
}

abstract class MemoryJson<T> implements DecodeEncode<T> {
  MemoryJson();

  /// Given a JSON string representing an array of HeapSample, decode to a
  /// List of HeapSample.
  MemoryJson.decode(
    String payloadName, {
    required String argJsonString,
    Map<String, dynamic>? argDecodedMap,
  }) {
    final Map<String, dynamic> decodedMap =
        argDecodedMap ?? jsonDecode(argJsonString);
    Map<String, dynamic> payload = decodedMap[payloadName];

    int payloadVersion = payload[jsonVersionField];
    final payloadDevToolsScreen = payload[jsonDevToolsScreenField];

    if (payloadVersion != version) {
      payload = upgradeToVersion(payload, payloadVersion);
      payloadVersion = version;
    }

    _memoryPayload = payloadDevToolsScreen == devToolsScreenValueMemory;
    _payloadVersion = payloadVersion;

    // Any problem return (data is empty).
    if (!isMatchedVersion || !isMemoryPayload) return;

    final List dynamicList = payload[jsonDataField];
    for (var index = 0; index < dynamicList.length; index++) {
      final sample = fromJson(dynamicList[index] as Map<String, dynamic>);
      data.add(sample);
    }
  }

  Map<String, dynamic> upgradeToVersion(
    Map<String, dynamic> payload,
    int oldVersion,
  );

  late final int _payloadVersion;

  int get payloadVersion => _payloadVersion;

  /// Imported JSON data loaded and converted, if necessary, to the latest version.
  bool get isMatchedVersion => _payloadVersion == version;

  late final bool _memoryPayload;

  /// JSON payload field "dart<T>DevToolsScreen" has a value of "memory" e.g.,
  ///   "dartDevToolsScreen": "memory"
  bool get isMemoryPayload => _memoryPayload;

  /// If data is empty check isMatchedVersion and isMemoryPayload to ensure the
  /// JSON file loaded is a memory file.
  final data = <T>[];

  static const String jsonDevToolsScreenField = 'dartDevToolsScreen';
  // TODO(terry): Expose Timeline.
  // const String _devToolsScreenValueTimeline = 'timeline';
  static const String devToolsScreenValueMemory = 'memory';
  static const String jsonVersionField = 'version';
  static const String jsonDataField = 'data';

  /// Trailer portion:
  static String get trailer => '\n]\n}}';
}

class SamplesMemoryJson extends MemoryJson<HeapSample> {
  SamplesMemoryJson();

  /// Given a JSON string representing an array of HeapSample, decode to a
  /// List of HeapSample.
  SamplesMemoryJson.decode({
    required String argJsonString,
    Map<String, dynamic>? argDecodedMap,
  }) : super.decode(
          _jsonMemoryPayloadField,
          argJsonString: argJsonString,
          argDecodedMap: argDecodedMap,
        );

  /// Exported JSON payload of collected memory statistics.
  static const String _jsonMemoryPayloadField = 'samples';

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
  /// Encoded Allocations entry (SamplesMemoryJson),
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

  @override
  int get version => HeapSample.version;

  /// Encoded Heap Sample
  @override
  String encode(HeapSample sample) => jsonEncode(sample);

  /// More than one Encoded Heap Sample, add a comma and the Encoded Heap Sample.
  @override
  String encodeAnother(HeapSample sample) => ',\n${jsonEncode(sample)}';

  @override
  HeapSample fromJson(Map<String, dynamic> json) => HeapSample.fromJson(json);

  @override
  Map<String, dynamic> upgradeToVersion(
    Map<String, dynamic> payload,
    int oldVersion,
  ) =>
      throw UnimplementedError(
        '${HeapSample.version} is the only valid HeapSample version',
      );

  /// Given a list of HeapSample, encode as a Json string.
  static String encodeList(List<HeapSample> data) {
    final samplesJson = SamplesMemoryJson();
    final result = StringBuffer();

    // Iterate over all HeapSamples collected.
    data.map((f) {
      final encodedValue = result.isNotEmpty
          ? samplesJson.encodeAnother(f)
          : samplesJson.encode(f);
      result.write(encodedValue);
    }).toList();

    return '$header$result${MemoryJson.trailer}';
  }

  static String get header => '{"$_jsonMemoryPayloadField": {'
      '"${MemoryJson.jsonVersionField}": ${HeapSample.version}, '
      '"${MemoryJson.jsonDevToolsScreenField}": "${MemoryJson.devToolsScreenValueMemory}", '
      '"${MemoryJson.jsonDataField}": [\n';
}

/// Structure of the memory JSON file:
///
/// {
///   "allocations": {
///     "version": 2,
///     "dartDevToolsScreen": "memory"
///     "data": [
///       Encoded ClassHeapStats see section below.
///     ]
///   }
/// }

/// Header portion (memoryJsonHeader) e.g.,
/// =======================================
/// {
///   "allocations": {
///     "version": 2,
///     "dartDevToolsScreen": "memory"
///     "data": [
///
/// Encoded Allocations entry (AllocationMemoryJson),
/// ==============================================================================
///     {
///       "class" : {
///          id: "classes/1"
///          name: "AClassName"
///        },
///       "instancesCurrent": 100,
///       "instancesAccumulated": 0,
///       "bytesCurrent": 55,
///       "accumulatedSize": 5,
///       "_new": [
///         100,
///         50,
///         5
///       ],
///       "_old": [
///         0,
///         0,
///         0
///       ]
///     },
///
/// Trailer portion (memoryJsonTrailer) e.g.,
/// =========================================
///     ]
///   }
/// }
class AllocationMemoryJson extends MemoryJson<ClassHeapStats> {
  AllocationMemoryJson();

  /// Given a JSON string representing an array of HeapSample, decode to a
  /// List of HeapSample.
  AllocationMemoryJson.decode({
    required String argJsonString,
    Map<String, dynamic>? argDecodedMap,
  }) : super.decode(
          _jsonAllocationPayloadField,
          argJsonString: argJsonString,
          argDecodedMap: argDecodedMap,
        );

  /// Exported JSON payload of collected memory statistics.
  static const String _jsonAllocationPayloadField = 'allocations';

  /// Encoded ClassHeapDetailStats
  @override
  String encode(ClassHeapStats sample) => jsonEncode(sample.json);

  /// More than one Encoded ClassHeapDetailStats, add a comma and the Encoded ClassHeapDetailStats entry.
  @override
  String encodeAnother(ClassHeapStats sample) =>
      ',\n${jsonEncode(sample.json)}';

  @override
  ClassHeapStats fromJson(Map<String, dynamic> json) =>
      ClassHeapStats.parse(json)!;

  @override
  Map<String, dynamic> upgradeToVersion(
    Map<String, dynamic> payload,
    int oldVersion,
  ) {
    assert(oldVersion < version);
    assert(oldVersion == 1);
    final updatedPayload = Map<String, dynamic>.of(payload);
    updatedPayload['version'] = version;
    final oldData = payload['data'];
    updatedPayload['data'] = [
      for (final data in oldData)
        {
          'type': 'ClassHeapStats',
          'class': <String, dynamic>{
            'type': '@Class',
            ...data['class'],
          },
          'bytesCurrent': data['bytesCurrent'],
          'accumulatedSize': data['bytesDelta'],
          'instancesCurrent': data['instancesCurrent'],
          'instancesAccumulated': data['instancesDelta'],
          // new and old space data is just reported as a list of ints
          '_new': <int>[
            // # of instances in new space.
            data['instancesCurrent'],
            // shallow memory consumption in new space.
            data['bytesCurrent'],
            // external memory consumption.
            0,
          ],
          // We'll just fudge the old space numbers.
          '_old': const <int>[0, 0, 0],
        },
    ];
    return updatedPayload;
  }

  @override
  int get version => allocationFormatVersion;

  static const int allocationFormatVersion = 2;

  /// Given a list of HeapSample, encode as a Json string.
  static String encodeList(List<ClassHeapStats> data) {
    final allocationJson = AllocationMemoryJson();

    final result = StringBuffer();

    // Iterate over all ClassHeapDetailStats collected.
    data.map((f) {
      final encodedValue = result.isNotEmpty
          ? allocationJson.encodeAnother(f)
          : allocationJson.encode(f);
      result.write(encodedValue);
    }).toList();

    return '$header$result${MemoryJson.trailer}';
  }

  /// Allocations Header portion:
  static String get header => '{"$_jsonAllocationPayloadField": {'
      '"${MemoryJson.jsonVersionField}": $allocationFormatVersion, '
      '"${MemoryJson.jsonDevToolsScreenField}": "${MemoryJson.devToolsScreenValueMemory}", '
      '"${MemoryJson.jsonDataField}": [\n';
}
