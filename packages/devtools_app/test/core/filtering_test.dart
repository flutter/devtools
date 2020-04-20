// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/core/filtering.dart';
import 'package:test/test.dart';

void main() {
  defineTests();
}

void defineTests() {
  group('Filter', () {
    test('compile', () async {
      var filter = Filter.compile('foo bar');
      expect(filter.items, hasLength(2));
      expect(filter.items[0].text, 'foo');
      expect(filter.items[1].negative, false);
      expect(filter.items[1].text, 'bar');
      expect(filter.items[1].negative, false);

      filter = Filter.compile('foo -bar');
      expect(filter.items, hasLength(2));
      expect(filter.items[0].negative, false);
      expect(filter.items[1].negative, true);

      // ignore empty terms
      filter = Filter.compile('foo');
      expect(filter.items, hasLength(1));

      filter = Filter.compile('foo ');
      expect(filter.items, hasLength(1));

      filter = Filter.compile('foo -');
      expect(filter.items, hasLength(1));
    });

    test('matches', () async {
      final items = ['foo', 'bar', 'baz'];

      // positive filter
      var filter = Filter.compile('foo');
      expect(applyFilter(filter, items), ['foo']);

      // negative filter
      filter = Filter.compile('-bar');
      expect(applyFilter(filter, items), ['foo', 'baz']);

      // escaped dash
      filter = Filter.compile(r'\-bar');
      expect(applyFilter(filter, ['foo', r'\-bar', 'baz']), [r'\-bar']);

      // positive and negative filter
      filter = Filter.compile('foo -bar');
      expect(applyFilter(filter, items), ['foo']);
      expect(
          applyFilter(filter, ['foo', 'foofoo', 'foobar']), ['foo', 'foofoo']);
    });
  });
}

List<String> applyFilter(Filter filter, List<String> items) {
  return items.where((element) {
    return filter.matches((String text) => element.contains(text));
  }).toList();
}
