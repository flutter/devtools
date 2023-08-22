// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterControllerMixin', () {
    late _TestController controller;

    void verifyBaseFilterState() {
      final activeFilter = controller.activeFilter.value;
      for (final toggleFilter in activeFilter.toggleFilters) {
        expect(
          toggleFilter.enabled.value,
          equals(toggleFilter.enabledByDefault),
        );
      }
      expect(activeFilter.queryFilter.isEmpty, isTrue);
    }

    setUp(() {
      controller = _TestController(_sampleData);
      expect(controller.data.length, equals(7));
      expect(controller.filteredData.value, isEmpty);
      verifyBaseFilterState();
    });

    test('setActiveFilter applies default filters', () {
      // Verify the default state of the active filter.
      final activeFilter = controller.activeFilter.value;
      expect(activeFilter.queryFilter.isEmpty, isTrue);
      expect(activeFilter.toggleFilters.length, equals(2));
      controller.setActiveFilter();

      expect(
        controller.filteredData.value.toString(),
        equals('[1-FooBar-foobar, 3-Baz-foobar, 5-Basset Hound-dog]'),
      );
    });

    test('filterData applies query and toggle filters', () {
      // Disable all toggle filters.
      for (final toggleFilter in controller.activeFilter.value.toggleFilters) {
        toggleFilter.enabled.value = false;
      }
      controller.setActiveFilter();
      expect(
        controller.filteredData.value.toString(),
        _sampleData.toString(),
      );

      // Only query filter.
      controller.setActiveFilter(query: 'Ba');
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[1-FooBar-foobar, 2-Bar-foobar, 3-Baz-foobar, 5-Basset Hound-dog]',
        ),
      );

      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[1-FooBar-foobar, 2-Bar-foobar, 3-Baz-foobar]'),
      );

      controller.setActiveFilter(query: 'Baz foo cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[0-Foo-foobar, 1-FooBar-foobar, 3-Baz-foobar]'),
      );

      // Ain't nothin' but a hound dog
      controller.setActiveFilter(query: 'Basset');
      expect(
        controller.filteredData.value.toString(),
        equals('[5-Basset Hound-dog]'),
      );

      // Only toggle filter.
      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter(
        toggleFilters: controller.toggleFilters,
      );
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[1-FooBar-foobar, 2-Bar-foobar, 4-Shepherd-dog, 5-Basset Hound-dog]',
        ),
      );

      // Query and toggle filter.
      controller.toggleFilters[0].enabled.value = true;
      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[1-FooBar-foobar]'),
      );

      // Excessive filter returns empty list.
      controller.toggleFilters[0].enabled.value = false;
      controller.toggleFilters[1].enabled.value = false;
      controller.setActiveFilter(query: 'abcdefg');
      expect(
        controller.filteredData.value.toString(),
        equals('[]'),
      );
    });

    test('isFilterActive', () {
      controller.toggleFilters[0].enabled.value = true;
      controller.toggleFilters[1].enabled.value = false;
      controller.setActiveFilter();
      expect(controller.isFilterActive, isTrue);

      controller.toggleFilters[0].enabled.value = false;
      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter();
      expect(controller.isFilterActive, isTrue);

      controller.toggleFilters[0].enabled.value = false;
      controller.toggleFilters[1].enabled.value = false;
      controller.setActiveFilter();
      expect(controller.isFilterActive, equals(false));

      controller.setActiveFilter(query: 'bar');
      expect(controller.isFilterActive, isTrue);

      controller.setActiveFilter(query: 'cat:foobar');
      expect(controller.isFilterActive, isTrue);
    });

    test('activeFilterTag', () {
      // No filters active.
      controller.toggleFilters[0].enabled.value = false;
      controller.toggleFilters[1].enabled.value = false;
      controller.setActiveFilter();
      expect(controller.activeFilterTag(), equals(''));

      // Only query filter active and no toggle filters.
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(controller.activeFilterTag(), 'ba cat:foobar');

      // Only toggle filter active and no query filters.
      controller.toggleFilters[0].enabled.value = true;
      controller.setActiveFilter();
      expect(controller.activeFilterTag(), equals('Hide multiples of 2'));

      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter();
      expect(
        controller.activeFilterTag(),
        equals('Hide multiples of 2,Hide multiples of 3'),
      );

      controller.toggleFilters[0].enabled.value = false;
      controller.setActiveFilter();
      expect(controller.activeFilterTag(), equals('Hide multiples of 3'));

      // Both query filter and toggle filters active.
      controller.toggleFilters[0].enabled.value = true;
      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.activeFilterTag(),
        equals(
          'Hide multiples of 2,Hide multiples of 3-#-ba cat:foobar',
        ),
      );
    });

    test('resetFilter', () {
      // Verify default state.
      controller.resetFilter();
      verifyBaseFilterState();

      controller.toggleFilters[0].enabled.value = true;
      controller.toggleFilters[1].enabled.value = true;
      controller.setActiveFilter(query: 'cat:foobar');
      for (final toggleFilter in controller.toggleFilters) {
        expect(toggleFilter.enabled.value, isTrue);
      }
      expect(controller.activeFilter.value.queryFilter.isEmpty, isFalse);

      controller.resetFilter();
      verifyBaseFilterState();
    });
  });
}

class _TestController extends DisposableController
    with FilterControllerMixin<_TestDataClass>, AutoDisposeControllerMixin {
  _TestController(this.data) {
    subscribeToFilterChanges();
  }

  final List<_TestDataClass> data;

  // Convenience getters for testing.
  List<ToggleFilter<_TestDataClass>> get toggleFilters =>
      activeFilter.value.toggleFilters;

  @override
  List<ToggleFilter<_TestDataClass>> createToggleFilters() => [
        ToggleFilter<_TestDataClass>(
          name: 'Hide multiples of 2',
          includeCallback: (data) => data.id % 2 != 0,
          enabledByDefault: true,
        ),
        ToggleFilter<_TestDataClass>(
          name: 'Hide multiples of 3',
          includeCallback: (data) => data.id % 3 != 0,
        ),
      ];

  static const categoryFilterId = 'category-filter';

  @override
  Map<String, QueryFilterArgument> createQueryFilterArgs() => {
        categoryFilterId: QueryFilterArgument(keys: ['cat', 'c']),
      };

  @override
  void filterData(Filter<_TestDataClass> filter) {
    super.filterData(filter);
    if (filter.isEmpty) {
      filteredData
        ..clear()
        ..addAll(data);
      return;
    }
    bool filterCallback(_TestDataClass element) {
      // First filter by the toggle filters.
      final toggleFilters = filter.toggleFilters;
      for (final toggleFilter in toggleFilters) {
        if (toggleFilter.enabled.value) {
          if (!toggleFilter.includeCallback(element)) return false;
        }
      }

      final queryFilter = filter.queryFilter;
      if (!queryFilter.isEmpty) {
        // Match the query argument to [_TestDataClass.category].
        final categoryArg =
            filter.queryFilter.filterArguments[categoryFilterId];
        if (categoryArg != null &&
            !categoryArg.matchesValue(element.category)) {
          return false;
        }

        // Match substrings to [_TestDataClass.label].
        if (queryFilter.substrings.isNotEmpty) {
          for (final substring in queryFilter.substrings) {
            bool matches(String? stringToMatch) {
              if (stringToMatch?.caseInsensitiveContains(substring) == true) {
                return true;
              }
              return false;
            }

            if (matches(element.label)) return true;
          }
          return false;
        }
      }

      return true;
    }

    filteredData
      ..clear()
      ..addAll(data.where(filterCallback));
  }
}

class _TestDataClass {
  const _TestDataClass(this.id, this.label, this.category);

  final int id;
  final String label;
  final String category;

  @override
  String toString() {
    return [id.toString(), label, category].join('-');
  }
}

const _sampleData = [
  _TestDataClass(0, 'Foo', 'foobar'),
  _TestDataClass(1, 'FooBar', 'foobar'),
  _TestDataClass(2, 'Bar', 'foobar'),
  _TestDataClass(3, 'Baz', 'foobar'),
  _TestDataClass(4, 'Shepherd', 'dog'),
  _TestDataClass(5, 'Basset Hound', 'dog'),
  _TestDataClass(6, 'Husky', 'dog'),
];
