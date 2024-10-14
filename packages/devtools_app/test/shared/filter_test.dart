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
      for (final filter in activeFilter.settingFilters) {
        expect(filter.setting.value, equals(filter.defaultValue));
      }
      expect(activeFilter.queryFilter.isEmpty, isTrue);
    }

    setUp(() {
      controller = _TestController(_sampleData);
      expect(controller.data.length, _sampleData.length);
      expect(controller.filteredData.value, isEmpty);
      verifyBaseFilterState();
    });

    test('setActiveFilter applies default filters', () {
      // Verify the default state of the active filter.
      final activeFilter = controller.activeFilter.value;
      expect(activeFilter.queryFilter.isEmpty, isTrue);
      expect(activeFilter.settingFilters.length, equals(3));
      controller.setActiveFilter();

      expect(
        controller.filteredData.value.toString(),
        equals(
          '[1-FooBar-foobar-3, 3-Baz-foobar-5, 5-Basset Hound-dog-3, 9-Meal bar-food-3]',
        ),
      );
    });

    test('filterData applies query and toggle filters', () {
      // Disable all toggle filters.
      controller.disableAllSettingFilters();
      expect(controller.useRegExp.value, isFalse);

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
          '[1-FooBar-foobar-3, 2-Bar-foobar-4, 3-Baz-foobar-5, 5-Basset Hound-dog-3, 9-Meal bar-food-3]',
        ),
      );

      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[1-FooBar-foobar-3, 2-Bar-foobar-4, 3-Baz-foobar-5]'),
      );

      controller.setActiveFilter(query: 'Baz foo cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[0-Foo-foobar-2, 1-FooBar-foobar-3, 3-Baz-foobar-5]'),
      );

      // Ain't nothin' but a hound dog
      controller.setActiveFilter(query: 'Basset');
      expect(
        controller.filteredData.value.toString(),
        equals('[5-Basset Hound-dog-3]'),
      );

      // Only toggle filter.
      controller.settingFilters[2].setting.value = true;
      controller.setActiveFilter(
        settingFilters: controller.settingFilters,
      );
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[1-FooBar-foobar-3, 2-Bar-foobar-4, 4-Shepherd-dog-1, 5-Basset Hound-dog-3, 7-Shepherd\'s pie-food-1, 8-Orange-food-2]',
        ),
      );

      // Query and toggle filter.
      controller.settingFilters[0].setting.value = 2;
      controller.settingFilters[1].setting.value = true;
      controller.settingFilters[2].setting.value = true;
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.filteredData.value.toString(),
        equals('[1-FooBar-foobar-3]'),
      );

      // Excessive filter returns empty list.
      controller.settingFilters[0].setting.value = 5;
      controller.settingFilters[1].setting.value = false;
      controller.settingFilters[2].setting.value = false;
      controller.setActiveFilter(query: 'abcdefg');
      expect(
        controller.filteredData.value.toString(),
        equals('[]'),
      );
    });

    test('filterData applies regexp query filters when enabled', () {
      // Disable all toggle filters.
      controller.disableAllSettingFilters();
      controller.useRegExp.value = true;

      controller.setActiveFilter();
      expect(
        controller.filteredData.value.toString(),
        _sampleData.toString(),
      );

      // Regexp filter argument match.
      controller.setActiveFilter(query: 'cat:foo.*');
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[0-Foo-foobar-2, 1-FooBar-foobar-3, 2-Bar-foobar-4, 3-Baz-foobar-5, 7-Shepherd\'s pie-food-1, 8-Orange-food-2, 9-Meal bar-food-3]',
        ),
      );
      controller.setActiveFilter(query: '-cat:foo.*');
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[4-Shepherd-dog-1, 5-Basset Hound-dog-3, 6-Husky-dog-5]',
        ),
      );
      // Regexp substring match.
      controller.setActiveFilter(query: '.*bar');
      expect(
        controller.filteredData.value.toString(),
        equals(
          '[1-FooBar-foobar-3, 2-Bar-foobar-4, 9-Meal bar-food-3]',
        ),
      );

      // Disable regexp filters and verify filter behavior changes.
      controller.useRegExp.value = false;

      // Regexp filter argument match.
      controller.setActiveFilter(query: 'cat:foo.*');
      expect(controller.filteredData.value, isEmpty);
      controller.setActiveFilter(query: '-cat:foo.*');
      expect(
        controller.filteredData.value.toString(),
        _sampleData.toString(),
      );

      // Regexp substring match.
      controller.setActiveFilter(query: '.*bar');
      expect(controller.filteredData.value, isEmpty);
    });

    test('isFilterActive', () {
      controller.settingFilters[0].setting.value = 1;
      controller.settingFilters[1].setting.value = true;
      controller.settingFilters[2].setting.value = false;
      controller.setActiveFilter();
      expect(controller.isFilterActive, true);

      controller.settingFilters[0].setting.value = 1;
      controller.settingFilters[1].setting.value = false;
      controller.settingFilters[2].setting.value = true;
      controller.setActiveFilter();
      expect(controller.isFilterActive, true);

      controller.settingFilters[0].setting.value = 2;
      controller.settingFilters[1].setting.value = false;
      controller.settingFilters[2].setting.value = false;
      controller.setActiveFilter();
      expect(controller.isFilterActive, true);

      controller.settingFilters[0].setting.value = 1;
      controller.settingFilters[1].setting.value = false;
      controller.settingFilters[2].setting.value = false;
      controller.setActiveFilter();
      expect(controller.isFilterActive, false);

      controller.setActiveFilter(query: 'bar');
      expect(controller.isFilterActive, true);

      controller.setActiveFilter(query: 'cat:foobar');
      expect(controller.isFilterActive, true);
    });

    test('activeFilterTag', () {
      // No filters active.
      controller.settingFilters[0].setting.value = 1;
      controller.settingFilters[1].setting.value = false;
      controller.settingFilters[2].setting.value = false;
      controller.setActiveFilter();
      expect(controller.activeFilterTag(), equals(''));

      // Only query filter active and no toggle filters.
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(controller.activeFilterTag(), 'ba cat:foobar');

      // Query filter with regular expressions enabled.
      controller.useRegExp.value = true;
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(controller.activeFilterTag(), 'ba cat:foobar-#-regexp');
      controller.useRegExp.value = false;

      // Only toggle filter active and no query filters.
      controller.settingFilters[0].setting.value = 3;
      controller.setActiveFilter();
      expect(
        controller.activeFilterTag(),
        equals('Hide items below the minimum rating level:3'),
      );

      controller.settingFilters[1].setting.value = true;
      controller.setActiveFilter();
      expect(
        controller.activeFilterTag(),
        equals(
          'Hide items below the minimum rating level:3,'
          'Hide multiples of 2:true',
        ),
      );

      controller.settingFilters[2].setting.value = true;
      controller.setActiveFilter();
      expect(
        controller.activeFilterTag(),
        equals(
          'Hide items below the minimum rating level:3,'
          'Hide multiples of 2:true,'
          'Hide multiples of 3:true',
        ),
      );

      controller.settingFilters[1].setting.value = false;
      controller.setActiveFilter();
      expect(
        controller.activeFilterTag(),
        equals(
          'Hide items below the minimum rating level:3,'
          'Hide multiples of 3:true',
        ),
      );

      // Both query filter and toggle filters active.
      controller.settingFilters[1].setting.value = true;
      controller.setActiveFilter(query: 'Ba cat:foobar');
      expect(
        controller.activeFilterTag(),
        equals(
          'Hide items below the minimum rating level:3,'
          'Hide multiples of 2:true,'
          'Hide multiples of 3:true'
          '-#-ba cat:foobar',
        ),
      );
    });

    test('resetFilter', () {
      // Verify default state.
      controller.resetFilter();
      verifyBaseFilterState();

      controller.settingFilters[0].setting.value = 5;
      controller.settingFilters[1].setting.value = true;
      controller.settingFilters[2].setting.value = true;
      controller.setActiveFilter(query: 'cat:foobar');
      for (final settingFilter in controller.settingFilters) {
        expect(settingFilter.enabled, isTrue);
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
  List<SettingFilter<_TestDataClass, Object>> get settingFilters =>
      activeFilter.value.settingFilters;

  @override
  List<SettingFilter<_TestDataClass, Object>> createSettingFilters() => [
        SettingFilter<_TestDataClass, int>(
          name: 'Hide items below the minimum rating level',
          includeCallback: (_TestDataClass element, int currentFilterValue) =>
              element.rating >= currentFilterValue,
          enabledCallback: (int filterValue) => filterValue > 1,
          possibleValues: [1, 2, 3, 4, 5],
          defaultValue: 2,
        ),
        ToggleFilter<_TestDataClass>(
          name: 'Hide multiples of 2',
          includeCallback: (data) => data.id % 2 != 0,
          defaultValue: true,
        ),
        ToggleFilter<_TestDataClass>(
          name: 'Hide multiples of 3',
          includeCallback: (data) => data.id % 3 != 0,
          defaultValue: false,
        ),
      ];

  static const categoryFilterId = 'category-filter';

  @override
  Map<String, QueryFilterArgument> createQueryFilterArgs() => {
        categoryFilterId: QueryFilterArgument<_TestDataClass>(
          keys: ['cat', 'c'],
          dataValueProvider: (data) => data.category,
          substringMatch: false,
        ),
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
      final filteredOutBySettingFilters = filter.settingFilters.any(
        (settingFilter) => !settingFilter.includeData(element),
      );
      if (filteredOutBySettingFilters) return false;

      final queryFilter = filter.queryFilter;
      if (!queryFilter.isEmpty) {
        final filteredOutByQueryFilterArgument = queryFilter
            .filterArguments.values
            .any((argument) => !argument.matchesValue(element));
        if (filteredOutByQueryFilterArgument) return false;

        // Match substrings to [_TestDataClass.label].
        if (queryFilter.substringExpressions.isNotEmpty) {
          for (final substring in queryFilter.substringExpressions) {
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

  void disableAllSettingFilters() {
    for (final filter in activeFilter.value.settingFilters) {
      if (filter is ToggleFilter) {
        filter.setting.value = false;
      } else {
        // This is the lowest setting for the integer setting filter.
        filter.setting.value = 1;
      }
    }
  }
}

class _TestDataClass {
  const _TestDataClass(this.id, this.label, this.category, this.rating);

  final int id;
  final String label;
  final String category;
  final int rating;

  @override
  String toString() {
    return [id.toString(), label, category, rating].join('-');
  }
}

const _sampleData = [
  _TestDataClass(0, 'Foo', 'foobar', 2),
  _TestDataClass(1, 'FooBar', 'foobar', 3),
  _TestDataClass(2, 'Bar', 'foobar', 4),
  _TestDataClass(3, 'Baz', 'foobar', 5),
  _TestDataClass(4, 'Shepherd', 'dog', 1),
  _TestDataClass(5, 'Basset Hound', 'dog', 3),
  _TestDataClass(6, 'Husky', 'dog', 5),
  _TestDataClass(7, 'Shepherd\'s pie', 'food', 1),
  _TestDataClass(8, 'Orange', 'food', 2),
  _TestDataClass(9, 'Meal bar', 'food', 3),
];
