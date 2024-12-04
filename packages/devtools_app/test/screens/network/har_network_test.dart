// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/network/constants.dart';
import 'package:devtools_app/src/screens/network/har_data_entry.dart';
import 'package:devtools_app/src/screens/network/har_network_data.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('test/test_infra/test_data/network/sample_requests.json');
  final fileContent = file.readAsStringSync();
  final jsonData = jsonDecode(fileContent) as Map<String, Object?>;

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

  group('HarDataEntry', () {
    test('fromJson parses correctly', () {
      final entryJson =
          ((jsonData['log'] as Map<String, Object?>)['entries'] as List).first
              as Map<String, Object?>;
      final harDataEntry = HarDataEntry.fromJson(entryJson);

      expect(
        harDataEntry.request.uri.toString(),
        'https://jsonplaceholder.typicode.com/albums/1',
      );
      expect(harDataEntry.request.method, 'GET');
      expect(harDataEntry.request.requestHeaders, isNotEmpty);
      expect(harDataEntry.request.requestCookies, isEmpty);
    });

    test('toJson serializes correctly', () {
      final entryJson =
          ((jsonData['log'] as Map<String, Object?>)['entries'] as List).first
              as Map<String, Object?>;
      final harDataEntry = HarDataEntry.fromJson(entryJson);
      final json = HarDataEntry.toJson(harDataEntry.request);

      expect(json['startedDateTime'], '2024-07-11T13:19:35.156Z');
      expect(json['request'], isNotNull);
      final request = json['request'] as Map<String, Object?>?;
      expect(request?['method'], 'GET');
      expect(request?['url'], 'https://jsonplaceholder.typicode.com/albums/1');
      expect(request?['httpVersion'], 'HTTP/1.1');
      expect(request?['cookies'], isEmpty);

      expect(json['cache'], isEmpty);
      final timings = json['timings'] as Map<String, Object?>?;
      expect(timings?['blocked'], NetworkEventDefaults.blocked);
      expect(timings?['dns'], NetworkEventDefaults.dns);
      expect(timings?['connect'], NetworkEventDefaults.connect);
      expect(timings?['send'], 1);
      expect(timings?['receive'], 1);
      expect(timings?['ssl'], NetworkEventDefaults.ssl);
      expect(json['comment'], '');
    });
  });
}
