// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

import '../test_infra/utils/variable_utils.dart';

void main() {
  setUp(() {
    resetRef();
    resetRoot();
  });

  group('childCount', () {
    group('for map instances', () {
      test('entire map', () {
        final map = buildMapVariable(length: 3);
        expect(map.childCount, equals(3));
      });
      test('map grouping with offset', () {
        final mapGrouping = buildMapGroupingVariable(
          length: 10,
          offset: 2,
          count: 4,
        );
        expect(mapGrouping.childCount, equals(4));
      });
      test('map grouping no offset', () {
        final mapGrouping = buildMapGroupingVariable(
          length: 10,
          offset: 0,
          count: 4,
        );
        expect(mapGrouping.childCount, equals(4));
      });
    });

    group('for list instances', () {
      test('entire list', () {
        final list = buildListVariable(length: 3);
        expect(list.childCount, equals(3));
      });
      test('list grouping with offset', () {
        final listGrouping = buildListGroupingVariable(
          length: 10,
          offset: 2,
          count: 4,
        );
        expect(listGrouping.childCount, equals(4));
      });
      test('list grouping no offset', () {
        final listGrouping = buildListGroupingVariable(
          length: 10,
          offset: 0,
          count: 4,
        );
        expect(listGrouping.childCount, equals(4));
      });
    });

    test('for booleans', () {
      final boolean = buildBooleanVariable(true);
      expect(boolean.childCount, equals(0));
    });

    test('for strings', () {
      final str = buildStringVariable('Hello there!');
      expect(str.childCount, equals(0));
    });
  });

  group('isPartialObject', () {
    group('for map instances', () {
      test('entire map', () {
        final map = buildMapVariable(length: 3);
        expect(map.isPartialObject, isFalse);
      });
      test('map grouping with offset', () {
        final mapGrouping = buildMapGroupingVariable(
          length: 10,
          offset: 2,
          count: 4,
        );
        expect(mapGrouping.isPartialObject, isTrue);
      });
      test('map grouping no offset', () {
        final mapGrouping = buildMapGroupingVariable(
          length: 10,
          offset: 0,
          count: 4,
        );
        expect(mapGrouping.isPartialObject, isTrue);
      });
    });

    group('for list instances', () {
      test('entire list', () {
        final list = buildListVariable(length: 3);
        expect(list.isPartialObject, isFalse);
      });
      test('list grouping with offset', () {
        final listGrouping = buildListGroupingVariable(
          length: 10,
          offset: 2,
          count: 4,
        );
        expect(listGrouping.isPartialObject, isTrue);
      });
      test('list grouping no offset', () {
        final listGrouping = buildListGroupingVariable(
          length: 10,
          offset: 0,
          count: 4,
        );
        expect(listGrouping.isPartialObject, isTrue);
      });
    });

    test('for booleans', () {
      final boolean = buildBooleanVariable(true);
      expect(boolean.isPartialObject, isFalse);
    });

    test('for strings', () {
      final str = buildStringVariable('Hello there!');
      expect(str.isPartialObject, isFalse);
    });
  });
}
