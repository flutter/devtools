// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/encoding.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  group('$OfflinePerformanceData', () {
    test('create empty data object', () {
      final offlineData = OfflinePerformanceData();
      expect(offlineData.perfettoTraceBinary, isNull);
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.rebuildCountModel, isNull);
      expect(offlineData.displayRefreshRate, 60.0);
      expect(offlineData.selectedTab, 0);
    });

    test('init from parse', () {
      OfflinePerformanceData offlineData = OfflinePerformanceData.fromJson({});
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.displayRefreshRate, equals(60.0));

      offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
      expect(offlineData.perfettoTraceBinary, isNotNull);
      expect(offlineData.frames.length, 3);
      expect(offlineData.selectedFrame, isNotNull);
      expect(offlineData.selectedFrame!.id, equals(2));
      expect(offlineData.displayRefreshRate, equals(60));
      expect(offlineData.rebuildCountModel, isNull);
      expect(offlineData.selectedTab, equals(0));
    });

    test('to json', () {
      OfflinePerformanceData offlineData = OfflinePerformanceData.fromJson({});
      expect(
        offlineData.toJson(),
        equals({
          OfflinePerformanceData.traceBinaryBase64Key: null,
          OfflinePerformanceData.flutterFramesKey: <Object?>[],
          OfflinePerformanceData.selectedFrameIdKey: null,
          OfflinePerformanceData.displayRefreshRateKey: 60,
          OfflinePerformanceData.rebuildCountModelKey: null,
          OfflinePerformanceData.selectedTabKey: 0,
        }),
      );

      offlineData = OfflinePerformanceData.fromJson(rawPerformanceData);
      final json = offlineData.toJson();
      final expectedTrace = Uint8List.fromList(
        (rawPerformanceData[OfflinePerformanceData.traceBinaryKey] as List)
            .cast<int>(),
      );
      expect(json.containsKey(OfflinePerformanceData.traceBinaryKey), isFalse);
      expect(
        Uint8List.sublistView(
          json[OfflinePerformanceData.traceBinaryBase64Key] as ByteData,
        ),
        equals(expectedTrace),
      );
      expect(
        {...json}..remove(OfflinePerformanceData.traceBinaryBase64Key),
        {...rawPerformanceData}..remove(OfflinePerformanceData.traceBinaryKey),
      );
    });

    group('trace binary encoding', () {
      final trace = Uint8List.fromList(
        List.generate(1 << 20, (i) => (i * 31) % 256),
      );

      test('round trips through JSON as a base64 string', () {
        final encoded = jsonEncode(
          OfflinePerformanceData(perfettoTraceBinary: trace).toJson(),
          toEncodable: toEncodable,
        );
        final json = jsonDecode(encoded) as Map<String, Object?>;
        expect(
          json[OfflinePerformanceData.traceBinaryBase64Key],
          isA<String>(),
        );
        expect(
          json.containsKey(OfflinePerformanceData.traceBinaryKey),
          isFalse,
        );
        // Base64 is ~1.33x the trace size, versus ~3.7x for a JSON number array.
        expect(encoded.length, lessThan(trace.length * 1.5));

        final parsed = OfflinePerformanceData.fromJson(json);
        expect(parsed.perfettoTraceBinary, equals(trace));
      });

      test('only encodes the bytes in a view of a larger buffer', () {
        final largerBuffer = Uint8List(trace.length * 2)
          ..setRange(0, trace.length, trace);
        final view = Uint8List.sublistView(largerBuffer, 0, trace.length);
        final encoded = jsonEncode(
          OfflinePerformanceData(perfettoTraceBinary: view).toJson(),
          toEncodable: toEncodable,
        );
        final parsed = OfflinePerformanceData.fromJson(
          jsonDecode(encoded) as Map<String, Object?>,
        );
        expect(parsed.perfettoTraceBinary, equals(trace));
      });

      test('loads an in-memory ByteData without encoding', () {
        final parsed = OfflinePerformanceData.fromJson(
          OfflinePerformanceData(perfettoTraceBinary: trace).toJson(),
        );
        expect(parsed.perfettoTraceBinary, equals(trace));
      });

      test('loads the legacy list of numbers format', () {
        final parsed = OfflinePerformanceData.fromJson({
          OfflinePerformanceData.traceBinaryKey: [1, 2, 3],
        });
        expect(
          parsed.perfettoTraceBinary,
          equals(Uint8List.fromList([1, 2, 3])),
        );
      });

      test('loads a legacy Uint8List', () {
        final parsed = OfflinePerformanceData.fromJson({
          OfflinePerformanceData.traceBinaryKey: trace,
        });
        expect(parsed.perfettoTraceBinary, same(trace));
      });

      test('is empty when no trace is present', () {
        expect(OfflinePerformanceData.fromJson({}).isEmpty, isTrue);
      });
    });

    test('round trips a non-zero selectedTab', () {
      final offlineData = OfflinePerformanceData(selectedTab: 2);
      final json = offlineData.toJson();
      expect(json[OfflinePerformanceData.selectedTabKey], equals(2));

      final parsed = OfflinePerformanceData.fromJson(json);
      expect(parsed.selectedTab, equals(2));
    });
  });

  group('$FlutterTimelineEvent', () {
    test('isUiEvent', () {
      depthFirstTraversal(
        FlutterFrame6.uiEvent,
        action: (node) {
          expect(
            node.isUiEvent,
            true,
            reason:
                'Expected ${node.name} event to have type '
                '${TimelineEventType.ui}.',
          );
        },
      );
    });

    test('isRasterFrameIdentifier', () {
      depthFirstTraversal(
        FlutterFrame6.rasterEvent,
        action: (node) {
          expect(
            node.isRasterEvent,
            true,
            reason:
                'Expected ${node.name} event to have type '
                '${TimelineEventType.raster}.',
          );
        },
      );
    });
  });
}
