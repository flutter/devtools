// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/timeline/timeline_utils.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:test/test.dart';

void main() {
  group('Timeline Utils', () {
    test('computeEventGroupKey for event with a set groupKey', () async {
      expect(computeEventGroupKey(httpEvent), equals('HTTP/client'));
    });

    test('computeEventGroupKey for UI event', () async {
      expect(computeEventGroupKey(goldenUiTimelineEvent), equals('UI'));
    });

    test('computeEventGroupKey for Raster event', () async {
      expect(computeEventGroupKey(goldenRasterTimelineEvent), equals('Raster'));
    });

    test('computeEventGroupKey for Async event', () async {
      expect(computeEventGroupKey(goldenAsyncTimelineEvent), equals('A'));
      // A child async event should return the key of its root.
      expect(computeEventGroupKey(asyncEventB), equals('A'));
    });

    test('computeEventGroupKey for Async event', () async {
      expect(computeEventGroupKey(gcEvent), equals('GC'));
    });

    test('computeEventGroupKey for Async event', () async {
      expect(computeEventGroupKey(unknownEvent), equals('Unknown'));
    });
  });
}
