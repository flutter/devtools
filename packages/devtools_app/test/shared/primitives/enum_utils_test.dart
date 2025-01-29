// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/enum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enum index ordering mixin', () {
    expect(Size.xs < Size.s, isTrue);
    expect(Size.xs <= Size.s, isTrue);
    expect(Size.xs > Size.s, isFalse);
    expect(Size.xs >= Size.s, isFalse);

    expect(Size.xl < Size.m, isFalse);
    expect(Size.xl <= Size.m, isFalse);
    expect(Size.xl > Size.m, isTrue);
    expect(Size.xl >= Size.m, isTrue);
  });
}

enum Size with EnumIndexOrdering { xs, s, m, xl }
