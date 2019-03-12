// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('utils', () {
    test('printMb', () {
      const int MB = 1024 * 1024;

      expect(printMb(10 * MB, 0), '10');
      expect(printMb(10 * MB), '10.0');
      expect(printMb(10 * MB, 1), '10.0');
      expect(printMb(10 * MB, 2), '10.00');

      expect(printMb(1000 * MB, 0), '1000');
      expect(printMb(1000 * MB), '1000.0');
      expect(printMb(1000 * MB, 1), '1000.0');
      expect(printMb(1000 * MB, 2), '1000.00');
    });

    test('msAsText', () {
      expect(msText(const Duration(microseconds: 3111)), equals('3.1 ms'));
      expect(
        msText(const Duration(microseconds: 3199), includeUnit: false),
        equals('3.2'),
      );
      expect(
        msText(const Duration(microseconds: 3159), fractionDigits: 2),
        equals('3.16 ms'),
      );
      expect(
        msText(const Duration(microseconds: 3111), fractionDigits: 3),
        equals('3.111 ms'),
      );
      expect(
        msText(const Duration(milliseconds: 3)),
        equals('3.0 ms'),
      );
    });

    test('nullSafeMin', () {
      expect(nullSafeMin(1, 2), equals(1));
      expect(nullSafeMin(1, null), equals(1));
      expect(nullSafeMin(null, 2), equals(2));
      expect(nullSafeMin(null, null), equals(null));
    });

    test('nullSafeMin', () {
      expect(nullSafeMax(1, 2), equals(2));
      expect(nullSafeMax(1, null), equals(1));
      expect(nullSafeMax(null, 2), equals(2));
      expect(nullSafeMax(null, null), equals(null));
    });

    test('log2', () {
      expect(log2(1), equals(0));
      expect(log2(1.5), equals(0));
      expect(log2(2), equals(1));
      expect(log2(3), equals(1));
      expect(log2(4), equals(2));
    });

    test('maybeExecuteWithDelay', () async {
      int n = 1;

      // Condition n >= 2 is false, so we should execute with a delay.
      maybeExecuteWithDelay(n >= 2, const Duration(milliseconds: 500), () => n++);
      expect(n, equals(1));
      await Future.delayed(const Duration(milliseconds: 250));
      expect(n, equals(1));
      await Future.delayed(const Duration(milliseconds: 250));
      expect(n, equals(2));

      // Condition n >= 2 is true, so we should not execute with a delay.
      maybeExecuteWithDelay(n >= 2, const Duration(milliseconds: 500), () => n++);
      expect(n, equals(3));
    });
  });
}
