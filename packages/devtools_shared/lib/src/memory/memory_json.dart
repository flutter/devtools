// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'heap_sample.dart';

/// Exported JSON payload of collected memory statistics.
const String _jsonPayloadField = 'samples';
const String _jsonVersionField = 'version';
const String _jsonDataField = 'data';

/// Given a list of HeapSample, encode as a Json string.
String memoryEncodeHeapSamples(List<HeapSample> data) {
  final result = StringBuffer();

  // Iterate over all HeapSamples collected.
  data.map((f) {
    final encode = result.isNotEmpty
        ? memoryEncodeAnotherHeapSample(f)
        : memoryEncodeHeapSample(f);
    result.write(encode);
  }).toList();

  return '$memoryJsonHeader$result$memoryJsonTrailer';
}

String get memoryJsonHeader => '{"$_jsonPayloadField": {'
    '"$_jsonVersionField": ${HeapSample.version}, "$_jsonDataField": [\n';

String get memoryJsonTrailer => '\n]\n}}';

/// Given a HeapSample, encode as a Json string.
String memoryEncodeHeapSample(HeapSample sample) => jsonEncode(sample);

/// Given another HeapSample, add the comma and encode as a Json string.
String memoryEncodeAnotherHeapSample(HeapSample sample) =>
    ',\n${jsonEncode(sample)}';

/// Given a JSON string representing an array of HeapSample, decode to a
/// List of HeapSample.
List<HeapSample> memoryDecodeHeapSamples(String jsonString) {
  final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
  final Map<String, dynamic> samplesPayload = decodedMap['$_jsonPayloadField'];

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
