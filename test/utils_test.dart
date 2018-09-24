// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/utils.dart';
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
  });
}
