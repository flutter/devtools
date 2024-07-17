// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/network/har_network_data.dart';

import 'package:flutter_test/flutter_test.dart';

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
      final log = json['log'] as Map<String, Object?>?;
      expect(log?['version'], '1.2');
      expect((log?['creator'] as Map<String, Object?>)['name'], 'devtools');

      final entries = log?['entries'] as List<Object?>?;
      expect(entries?.length, 2);

      final entry = entries?[0] as Map<String, Object?>?;
      expect(entry?['startedDateTime'], '2024-07-11T13:19:35.156Z');
      expect((entry?['request'] as Map<String, Object?>)['method'], 'GET');
      expect(
        (entry?['request'] as Map<String, Object?>)['url'],
        'https://jsonplaceholder.typicode.com/albums/1',
      );
      expect(
        (entry?['request'] as Map<String, Object?>)['httpVersion'],
        'HTTP/1.1',
      );
      expect((entry?['request'] as Map<String, Object?>)['cookies'], isEmpty);

      expect(entry?['cache'], isEmpty);
      expect((entry?['timings'] as Map<String, Object?>)['blocked'], -1);
      expect((entry?['timings'] as Map<String, Object?>)['dns'], -1);
      expect((entry?['timings'] as Map<String, Object?>)['connect'], -1);
      expect((entry?['timings'] as Map<String, Object?>)['send'], 1);
      expect((entry?['timings'] as Map<String, Object?>)['receive'], 1);
      expect((entry?['timings'] as Map<String, Object?>)['ssl'], -1);
      expect(entry?['comment'], '');
    });
  });
}
