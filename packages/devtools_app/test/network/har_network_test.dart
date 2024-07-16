// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/network/har_network_data.dart';

import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: avoid_dynamic_calls

void main() {
  final file = File('test/network/sample_requests.json');
  final fileContent = file.readAsStringSync();
  final jsonData = jsonDecode(fileContent);
  group('HarNetworkData', () {
    test('toJson serializes correctly', () {
      // Parse the HAR data
      final harData = HarNetworkData.fromJson(jsonData);

      // Serialize the HAR data back to JSON
      final json = harData.toJson();

      // Verify the serialization
      expect(json['log'], isNotNull);
      final log = json['log'] as Map<String, dynamic>?;
      expect(log?['version'], '1.2');
      expect(log?['creator']?['name'], 'devtools');

      final entries = log?['entries'] as List<dynamic>?;
      expect(entries?.length, 2);

      final entry = entries?[0] as Map<String, dynamic>?;
      expect(entry?['startedDateTime'], '2024-07-11T13:19:35.156Z');
      expect(entry?['request']?['method'], 'GET');
      expect(
        entry?['request']?['url'],
        'https://jsonplaceholder.typicode.com/albums/1',
      );
      expect(entry?['request']?['httpVersion'], 'HTTP/1.1');
      expect(entry?['request']?['cookies'], isEmpty);

      expect(entry?['cache'], isEmpty);
      expect(entry?['timings']?['blocked'], -1);
      expect(entry?['timings']?['dns'], -1);
      expect(entry?['timings']?['connect'], -1);
      expect(entry?['timings']?['send'], 1);
      expect(entry?['timings']?['receive'], 1);
      expect(entry?['timings']?['ssl'], -1);
      expect(entry?['comment'], '');
    });
  });
}
