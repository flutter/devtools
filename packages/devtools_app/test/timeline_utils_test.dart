// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/performance/performance_utils.dart';
import 'package:devtools_testing/support/performance_test_data.dart';
import 'package:test/test.dart';

void main() {
  group('Timeline Utils', () {
    test('computeEventGroupKey for event with a set groupKey', () async {
      expect(
        computeEventGroupKey(httpEvent, threadNamesById),
        equals('HTTP/client'),
      );
    });

    test('computeEventGroupKey for UI event', () async {
      expect(
        computeEventGroupKey(goldenUiTimelineEvent, threadNamesById),
        equals('UI'),
      );
    });

    test('computeEventGroupKey for Raster event', () async {
      expect(
        computeEventGroupKey(goldenRasterTimelineEvent, threadNamesById),
        equals('Raster'),
      );
    });

    test('computeEventGroupKey for Async event', () async {
      expect(
        computeEventGroupKey(goldenAsyncTimelineEvent, threadNamesById),
        equals('A'),
      );
      // A child async event should return the key of its root.
      expect(computeEventGroupKey(asyncEventB, threadNamesById), equals('A'));
    });

    test('computeEventGroupKey for event with named thread', () {
      expect(
        computeEventGroupKey(eventForNamedThread, threadNamesById),
        equals('io.flutter.1.platform (775)'),
      );
    });

    test('computeEventGroupKey for unknown event', () async {
      expect(
        computeEventGroupKey(unknownEvent, threadNamesById),
        equals('Unknown'),
      );
    });
  });
}
