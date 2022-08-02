// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/performance/panes/frame_analysis/frame_analysis_model.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_data/performance.dart';

void main() {
  group('FrameAnalysis', () {
    late FlutterFrame frame;
    late FrameAnalysis frameAnalysis;

    setUp(() {
      frame = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
    });

    test('buildPhase', () {
      final buildPhase = frameAnalysis.buildPhase;
      expect(buildPhase.events.length, equals(2));
      expect(buildPhase.duration.inMicroseconds, equals(83));
    });

    test('layoutPhase', () {
      final layoutPhase = frameAnalysis.layoutPhase;
      expect(layoutPhase.events.length, equals(1));
      expect(layoutPhase.duration.inMicroseconds, equals(128));
    });

    test('paintPhase', () {
      final paintPhase = frameAnalysis.paintPhase;
      expect(paintPhase.events.length, equals(1));
      expect(paintPhase.duration.inMicroseconds, equals(74));
    });

    test('rasterPhase', () {
      final rasterPhase = frameAnalysis.rasterPhase;
      expect(rasterPhase.events.length, equals(1));
      expect(rasterPhase.duration.inMicroseconds, equals(28404));
    });

    test('longestFramePhase', () {
      expect(frameAnalysis.longestUiPhase.title, equals('Layout'));
    });

    test('saveLayerCount', () {
      expect(frameAnalysis.saveLayerCount, equals(1));

      frame = testFrame0.shallowCopy()
        ..setEventFlow(compositingEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.saveLayerCount, equals(0));
    });

    test('intrinsicOperationsCount', () {
      expect(frameAnalysis.intrinsicOperationsCount, equals(2));

      frame = testFrame0.shallowCopy()
        ..setEventFlow(compositingEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.intrinsicOperationsCount, equals(0));
    });

    test('hasExpensiveOperations', () {
      expect(frameAnalysis.hasExpensiveOperations, isTrue);

      frame = testFrame0.shallowCopy()
        ..setEventFlow(compositingEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.hasExpensiveOperations, isFalse);
    });
  });
}
