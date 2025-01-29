// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$ClassFilter', () {
    test('task for ${ClassFilterType.except}', () {
      final weaker = _exceptFilter('a');
      final stronger = _exceptFilter('a\nb');

      expect(stronger.task(previous: weaker), FilteringTask.reuse);
      expect(weaker.task(previous: stronger), FilteringTask.refilter);
      expect(weaker.task(previous: weaker), FilteringTask.doNothing);
    });

    test('task for ${ClassFilterType.only}', () {
      final weaker = _onlyFilter('a\nb');
      final stronger = _onlyFilter('a');

      expect(stronger.task(previous: weaker), FilteringTask.reuse);
      expect(weaker.task(previous: stronger), FilteringTask.refilter);
      expect(weaker.task(previous: weaker), FilteringTask.doNothing);
    });

    test('task for ${ClassFilterType.showAll}', () {
      final f1 = _allFilter('a', '');
      final f2 = _allFilter('', 'b');

      expect(f1.task(previous: f2), FilteringTask.doNothing);
      expect(f2.task(previous: f1), FilteringTask.doNothing);
      expect(f1.task(previous: f1), FilteringTask.doNothing);
    });
  });
}

ClassFilter _exceptFilter(String filter) =>
    ClassFilter(filterType: ClassFilterType.except, except: filter, only: '');

ClassFilter _onlyFilter(String filter) =>
    ClassFilter(filterType: ClassFilterType.only, except: '', only: filter);

ClassFilter _allFilter(String only, String except) => ClassFilter(
  filterType: ClassFilterType.showAll,
  except: except,
  only: only,
);
