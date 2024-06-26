// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/performance/sample_performance_data.dart';

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
        equals(10010),
      );
      expect(
        testFrameWithSubtleShaderJank.shaderDuration.inMicroseconds,
        equals(3010),
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
  });
}
