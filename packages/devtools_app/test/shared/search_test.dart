// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

// TODO(https://github.com/flutter/devtools/issues/3514): increase test coverage

void main() {
  late TestSearchController searchController;

  final testData = <TestSearchData>[
    TestSearchData('Foo'),
    TestSearchData('Bar'),
    TestSearchData('FooBar'),
    TestSearchData('Baz'),
    TestSearchData('FooBaz'),
  ];

  group('SearchControllerMixin', () {
    setUp(() {
      searchController = TestSearchController()..data.addAll(testData);
    });

    test('updates values for query', () {
      expect(searchController.search, isEmpty);
      expect(searchController.searchMatches.value, isEmpty);

      searchController.search = 'foo';

      expect(searchController.search, equals('foo'));
      expect(searchController.searchMatches.value.length, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));
      expect(searchController.matchIndex.value, equals(1));
      for (final data in testData) {
        if (data.name.caseInsensitiveContains('foo')) {
          expect(data.isSearchMatch, isTrue);
        } else {
          expect(data.isSearchMatch, isFalse);
        }
      }
    });

    test('updates values for empty query', () {
      searchController.search = 'foo';
      expect(searchController.search, equals('foo'));
      expect(searchController.searchMatches.value.length, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));
      expect(searchController.matchIndex.value, equals(1));
      for (final data in testData) {
        if (data.name.caseInsensitiveContains('foo')) {
          expect(data.isSearchMatch, isTrue);
        } else {
          expect(data.isSearchMatch, isFalse);
        }
      }

      // Set the search query to the empty string
      searchController.search = '';
      expect(searchController.search, equals(''));
      expect(searchController.searchMatches.value, isEmpty);
      expect(searchController.activeSearchMatch.value, isNull);
      expect(searchController.matchIndex.value, equals(0));
      for (final data in testData) {
        expect(data.isSearchMatch, isFalse);
      }
    });
  });
}

class TestSearchController extends DisposableController
    with SearchControllerMixin<TestSearchData> {
  final data = <TestSearchData>[];

  @override
  List<TestSearchData> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    return data
        .where((element) => element.name.caseInsensitiveContains(search))
        .toList();
  }
}

class TestSearchData with SearchableDataMixin {
  TestSearchData(this.name);

  final String name;
}
