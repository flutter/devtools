// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/performance/performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/performance_test_data.dart';

void main() {
  group('PerformanceUtils', () {
    test('computeEventGroupKey for event with a set groupKey', () async {
      expect(
        PerformanceUtils.computeEventGroupKey(httpEvent, threadNamesById),
        equals('HTTP/client'),
      );
    });

    test('computeEventGroupKey for UI event', () async {
      expect(
        PerformanceUtils.computeEventGroupKey(
            goldenUiTimelineEvent, threadNamesById),
        equals('UI'),
      );
    });

    test('computeEventGroupKey for Raster event', () async {
      expect(
        PerformanceUtils.computeEventGroupKey(
            goldenRasterTimelineEvent, threadNamesById),
        equals('Raster'),
      );
    });

    test('computeEventGroupKey for Async event', () async {
      expect(
        PerformanceUtils.computeEventGroupKey(
            goldenAsyncTimelineEvent, threadNamesById),
        equals('A'),
      );
      // A child async event should return the key of its root.
      expect(
          PerformanceUtils.computeEventGroupKey(asyncEventB, threadNamesById),
          equals('A'));
    });

    test('computeEventGroupKey for event with named thread', () {
      expect(
        PerformanceUtils.computeEventGroupKey(
            eventForNamedThread, threadNamesById),
        equals('io.flutter.1.platform (775)'),
      );
    });

    test('computeEventGroupKey for unknown event', () async {
      expect(
        PerformanceUtils.computeEventGroupKey(unknownEvent, threadNamesById),
        equals('Unknown'),
      );
    });

    test('event bucket compare', () {
      expect(PerformanceUtils.eventGroupComparator('UI', 'Raster'), equals(-1));
      expect(PerformanceUtils.eventGroupComparator('Raster', 'UI'), equals(1));
      expect(PerformanceUtils.eventGroupComparator('UI', 'UI'), equals(0));
      expect(PerformanceUtils.eventGroupComparator('UI', 'Async'), equals(-1));
      expect(PerformanceUtils.eventGroupComparator('A', 'B'), equals(-1));
      expect(PerformanceUtils.eventGroupComparator('Z', 'Unknown'), equals(1));
      expect(PerformanceUtils.eventGroupComparator('Unknown', 'Unknown'),
          equals(0));
      expect(PerformanceUtils.eventGroupComparator('Unknown', 'Unknown (1234)'),
          equals(-1));
      expect(
          PerformanceUtils.eventGroupComparator(
              'Unknown (2345)', 'Unknown (1234)'),
          equals(1));
      expect(PerformanceUtils.eventGroupComparator('Unknown', 'Warm up shader'),
          equals(1));
      expect(PerformanceUtils.eventGroupComparator('UI', 'SHADE'), equals(1));
      expect(
          PerformanceUtils.eventGroupComparator('Raster', 'SHADE'), equals(1));
      expect(PerformanceUtils.eventGroupComparator('SHADE', 'Warm up shader'),
          equals(-1));
      expect(PerformanceUtils.eventGroupComparator('Warm up shader', 'A'),
          equals(-1));
    });
  });
}
