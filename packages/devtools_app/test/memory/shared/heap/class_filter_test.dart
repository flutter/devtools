// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('$ClassFilter parses filters.', () {
    final filter = ClassFilter(
      filterType: ClassFilterType.except,
      except: 'f1, f2 \n f3 ',
      only: '',
    );

    expect(filter.filters, {'f1', 'f2', 'f3'});
  });
}
