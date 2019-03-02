// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
      expect(msAsText(3.111), equals('3.1 ms'));
      expect(msAsText(3.111, includeUnit: false), equals('3.1'));
      expect(msAsText(3.111, fractionDigits: 3), equals('3.111 ms'));
      expect(msAsText(3), equals('3.0 ms'));
    });

    test('microsAsMsText', () {
      expect(microsAsMsText(3111), equals('3.1 ms'));
      expect(microsAsMsText(3111, includeUnit: false), equals('3.1'));
      expect(microsAsMsText(3111, fractionDigits: 3), equals('3.111 ms'));
      expect(microsAsMsText(3000), equals('3.0 ms'));
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
  });
}
