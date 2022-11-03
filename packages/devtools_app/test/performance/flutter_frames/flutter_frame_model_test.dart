// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_data/performance.dart';

void main() {
  group('$FlutterFrame', () {
    test('shaderDuration', () {
      expect(testFrame0.shaderDuration.inMicroseconds, equals(0));
      expect(testFrame1.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrame.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrameUiOnly.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrameRasterOnly.shaderDuration.inMicroseconds, equals(0));
      expect(
        testFrameWithShaderJank.shaderDuration.inMicroseconds,
        equals(50000),
      );
      expect(
        testFrameWithSubtleShaderJank.shaderDuration.inMicroseconds,
        equals(4000),
      );
    });

    test('hasShaderTime', () {
      expect(testFrame0.hasShaderTime, isFalse);
      expect(testFrame1.hasShaderTime, isFalse);
      expect(jankyFrame.hasShaderTime, isFalse);
      expect(jankyFrameUiOnly.hasShaderTime, isFalse);
      expect(jankyFrameRasterOnly.hasShaderTime, isFalse);
      expect(testFrameWithShaderJank.hasShaderTime, isTrue);
      expect(testFrameWithSubtleShaderJank.hasShaderTime, isTrue);
    });

    test('hasShaderJank', () {
      expect(testFrame0.hasShaderJank(defaultRefreshRate), isFalse);
      expect(testFrame1.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrame.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrameUiOnly.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrameRasterOnly.hasShaderJank(defaultRefreshRate), isFalse);
      expect(testFrameWithShaderJank.hasShaderJank(defaultRefreshRate), isTrue);
      expect(
        testFrameWithSubtleShaderJank.hasShaderJank(defaultRefreshRate),
        isFalse,
      );
    });

    test(
        'UI event flow sets frame.timeFromEventFlows end time if it completes after raster event flow',
        () {
      final uiEvent = goldenUiTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 5000)
          ..end = const Duration(microseconds: 8000));
      final rasterEvent = goldenRasterTimelineEvent.deepCopy()
        ..time = (TimeRange()
          ..start = const Duration(microseconds: 6000)
          ..end = const Duration(microseconds: 7000));

      final frame = FlutterFrame.parse({
        'number': 1,
        'startTime': 100,
        'elapsed': 200,
        'build': 40,
        'raster': 50,
        'vsyncOverhead': 10,
      });
      frame.setEventFlow(rasterEvent, type: TimelineEventType.raster);
      expect(frame.timeFromEventFlows.start, isNull);
      expect(frame.timeFromEventFlows.end, isNull);

      frame.setEventFlow(uiEvent, type: TimelineEventType.ui);
      expect(
        frame.timeFromEventFlows.start,
        equals(const Duration(microseconds: 5000)),
      );
      expect(
        frame.timeFromEventFlows.end,
        equals(const Duration(microseconds: 8000)),
      );
    });
  });
}
