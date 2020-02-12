// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'heap_sample.dart';

/// Exported JSON payload of collected memory statistics.
class MemoryJson {
  static const String _jsonPayloadField = 'samples';
  static const String _jsonVersionField = 'version';
  static const String _jsonDataField = 'data';

  /// Given a list of HeapSample, encode as a Json string.
  String encodeHeapSamples(List<HeapSample> data) {
    final result = StringBuffer();

    // Iterate over all HeapSamples collected.
    data.map((f) {
      final encode =
          result.isNotEmpty ? encodeAnotherHeapSample(f) : encodeHeapSample(f);
      result.write(encode);
    }).toList();

    return '$jsonHeader$result$jsonTrailer';
  }

  String get jsonHeader => '{"$_jsonPayloadField": {'
      '"$_jsonVersionField": ${HeapSample.version}, "$_jsonDataField": [\n';

  String get jsonTrailer => '\n]\n}}';

  /// Given a HeapSample, encode as a Json string.
  String encodeHeapSample(HeapSample sample) => jsonEncode(sample);

  /// Given another HeapSample, add the comma and encode as a Json string.
  String encodeAnotherHeapSample(HeapSample sample) =>
      ',\n${jsonEncode(sample)}';

  /// Given a JSON string representing an array of HeapSample, decode to a
  /// List of HeapSample.
  List<HeapSample> decodeHeapSamples(String jsonString) {
    final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
    final Map<String, dynamic> samplesPayload =
        decodedMap['$_jsonPayloadField'];

    final payloadVersion = samplesPayload['$_jsonVersionField'];

    // TODO(terry): Different JSON payload version conversions TBD - only one version today.
    assert(payloadVersion == HeapSample.version);

    final List dynamicList = samplesPayload['$_jsonDataField'];
    final List<HeapSample> samples = [];
    for (var index = 0; index < dynamicList.length; index++) {
      final sample = HeapSample.fromJson(dynamicList[index]);
      samples.add(sample);
    }

    return samples;
  }
}
