// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/math_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sum', () {
    expect(sum([1.0, 2.0, 3.0]), 6.0);
  });
  test('minimum', () {
    expect(min([1.0, 2.0, 3.0]), 1.0);
  });
  test('maximum', () {
    expect(max([1.0, 2.0, 3.0]), 3.0);
  });
}
