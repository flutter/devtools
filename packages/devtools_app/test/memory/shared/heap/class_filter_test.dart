// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/shared/memory/class_name.dart';
import 'package:flutter_test/flutter_test.dart';

final _class1 =
    HeapClassName.fromPath(className: 'class1', library: 'library1');
final _class2 =
    HeapClassName.fromPath(className: 'class2', library: 'library2');
final _class3 =
    HeapClassName.fromPath(className: 'class3', library: 'library3');
final _class4 =
    HeapClassName.fromPath(className: 'class4', library: 'library4');

final _data = <HeapClassName>[_class1, _class2, _class3, _class4];

void main() {
  test('$ClassFilter parses filters.', () {
    final filter = ClassFilter(
      filterType: ClassFilterType.except,
      except: 'f1, f2 \n f3 ',
      only: '',
    );

    expect(filter.filters, {'f1', 'f2', 'f3'});
  });

  test('$ClassFilter.filter is noop when not selected filter changes.', () {
    final filter1 = ClassFilter(
      filterType: ClassFilterType.except,
      except: 'class1, library2, library3/class3',
      only: '',
    );

    final result1 = ClassFilter.filter(
      oldFilter: null,
      newFilter: filter1,
      oldFiltered: null,
      original: _data,
      extractClass: (c) => c,
      rootPackage: null,
    );

    expect(result1, [_class4]);

    final filter2 = ClassFilter(
      filterType: ClassFilterType.except,
      except: filter1.except,
      only: 'something',
    );

    final result2 = ClassFilter.filter(
      oldFilter: filter1,
      newFilter: filter2,
      oldFiltered: result1,
      original: _data,
      extractClass: (c) => c,
      rootPackage: null,
    );

    expect(result2, result1);
  });
}
