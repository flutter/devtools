// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/controller/filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$ClassFilter', () {
    test('task returns correct task for ${ClassFilterType.except}', () {
      final shortFilter = _exceptFilter('a');
      final longFilter = _exceptFilter('a\nb');

      expect(longFilter.task(previous: shortFilter), FilteringTask.reuse);
      expect(shortFilter.task(previous: longFilter), FilteringTask.refilter);
      expect(longFilter.task(previous: longFilter), FilteringTask.doNothing);
    });

    test('task returns correct task for ${ClassFilterType.only}', () {
      final shortFilter = _onlyFilter('a');
      final longFilter = _onlyFilter('a\nb');

      expect(longFilter.task(previous: shortFilter), FilteringTask.refilter);
      expect(shortFilter.task(previous: longFilter), FilteringTask.reuse);
      expect(longFilter.task(previous: longFilter), FilteringTask.doNothing);
    });
  });
}

ClassFilter _exceptFilter(String filter) =>
    ClassFilter(filterType: ClassFilterType.except, except: filter, only: '');

ClassFilter _onlyFilter(String filter) =>
    ClassFilter(filterType: ClassFilterType.only, except: '', only: filter);
