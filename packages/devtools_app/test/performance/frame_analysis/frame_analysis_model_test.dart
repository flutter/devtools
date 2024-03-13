// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  group('FrameAnalysis', () {
    late FlutterFrame frame;
    late FrameAnalysis frameAnalysis;

    setUp(() {
      frame = FlutterFrame4.frameWithExtras;
      frameAnalysis = FrameAnalysis(frame);
    });

    test('buildPhase', () {
      final buildPhase = frameAnalysis.buildPhase;
      expect(buildPhase.events.length, equals(3));
      expect(buildPhase.duration.inMicroseconds, equals(1004));
    });

    test('layoutPhase', () {
      final layoutPhase = frameAnalysis.layoutPhase;
      expect(layoutPhase.events.length, equals(1));
      expect(layoutPhase.duration.inMicroseconds, equals(28));
    });

    test('paintPhase', () {
      final paintPhase = frameAnalysis.paintPhase;
      expect(paintPhase.events.length, equals(1));
      expect(paintPhase.duration.inMicroseconds, equals(21));
    });

    test('rasterPhase', () {
      final rasterPhase = frameAnalysis.rasterPhase;
      expect(rasterPhase.events.length, equals(1));
      expect(rasterPhase.duration.inMicroseconds, equals(4412));
    });

    test('longestFramePhase', () {
      expect(frameAnalysis.longestUiPhase.title, equals('Build'));
    });

    test('saveLayerCount', () {
      expect(frameAnalysis.saveLayerCount, equals(1));

      frame = FlutterFrame4.frame;
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.saveLayerCount, equals(0));
    });

    test('intrinsicOperationsCount', () {
      expect(frameAnalysis.intrinsicOperationsCount, equals(2));

      frame = FlutterFrame4.frame;
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.intrinsicOperationsCount, equals(0));
    });

    test('hasExpensiveOperations', () {
      expect(frameAnalysis.hasExpensiveOperations, isTrue);

      frame = FlutterFrame4.frame;
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.hasExpensiveOperations, isFalse);
    });

    test('calculateFramePhaseFlexValues', () {
      expect(frameAnalysis.buildFlex, isNull);
      expect(frameAnalysis.layoutFlex, isNull);
      expect(frameAnalysis.paintFlex, isNull);
      expect(frameAnalysis.rasterFlex, isNull);
      expect(frameAnalysis.shaderCompilationFlex, isNull);

      frameAnalysis.calculateFramePhaseFlexValues();

      expect(frameAnalysis.buildFlex, equals(95));
      expect(frameAnalysis.layoutFlex, equals(3));
      expect(frameAnalysis.paintFlex, equals(2));
      expect(frameAnalysis.rasterFlex, equals(1));
      expect(frameAnalysis.shaderCompilationFlex, isNull);

      frame = testFrameWithShaderJank;
      frameAnalysis = FrameAnalysis(frame);

      frameAnalysis.calculateFramePhaseFlexValues();

      expect(frameAnalysis.buildFlex, equals(95));
      expect(frameAnalysis.layoutFlex, equals(3));
      expect(frameAnalysis.paintFlex, equals(2));
      expect(frameAnalysis.rasterFlex, equals(86));
      expect(frameAnalysis.shaderCompilationFlex, equals(14));
    });
  });
}
