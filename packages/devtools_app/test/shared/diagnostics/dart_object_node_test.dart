// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/utils/variable_utils.dart';

void main() {
  setUp(() {
    resetRef();
    resetRoot();
  });

  group('map instances', () {
    test('entire map', () {
      final map = buildMapVariable(length: 3);
      expect(map.childCount, equals(3));
      expect(map.isPartialObject, isFalse);
    });

    test('map grouping with offset', () {
      final mapGrouping = buildMapGroupingVariable(
        length: 10,
        offset: 2,
        count: 4,
      );
      expect(mapGrouping.childCount, equals(4));
      expect(mapGrouping.isPartialObject, isTrue);
    });

    test('map grouping no offset', () {
      final mapGrouping = buildMapGroupingVariable(
        length: 10,
        offset: 0,
        count: 4,
      );
      expect(mapGrouping.childCount, equals(4));
      expect(mapGrouping.isPartialObject, isTrue);
    });
  });

  group('list instances', () {
    test('entire list', () {
      final list = buildListVariable(length: 3);
      expect(list.childCount, equals(3));
      expect(list.isPartialObject, isFalse);
    });
    test('list grouping with offset', () {
      final listGrouping = buildListGroupingVariable(
        length: 10,
        offset: 2,
        count: 4,
      );
      expect(listGrouping.childCount, equals(4));
      expect(listGrouping.isPartialObject, isTrue);
    });
    test('list grouping no offset', () {
      final listGrouping = buildListGroupingVariable(
        length: 10,
        offset: 0,
        count: 4,
      );
      expect(listGrouping.childCount, equals(4));
      expect(listGrouping.isPartialObject, isTrue);
    });
  });

  group('set instances', () {
    test('entire set', () {
      final set = buildSetVariable(length: 3);
      expect(set.childCount, equals(3));
      expect(set.isPartialObject, isFalse);
    });

    test('set grouping with offset', () {
      final setGrouping = buildSetGroupingVariable(
        length: 10,
        offset: 2,
        count: 4,
      );
      expect(setGrouping.childCount, equals(4));
      expect(setGrouping.isPartialObject, isTrue);
    });

    test('set grouping no offset', () {
      final setGrouping = buildSetGroupingVariable(
        length: 10,
        offset: 0,
        count: 4,
      );
      expect(setGrouping.childCount, equals(4));
      expect(setGrouping.isPartialObject, isTrue);
    });
  });

  test('booleans', () {
    final boolean = buildBooleanVariable(true);
    expect(boolean.childCount, equals(0));
    expect(boolean.isPartialObject, isFalse);
  });

  test('strings', () {
    final str = buildStringVariable('Hello there!');
    expect(str.childCount, equals(0));
    expect(str.isPartialObject, isFalse);
  });
}
