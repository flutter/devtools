// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../primitives/class_name.dart';

enum ClassFilterType {
  all,
  except,
  only,
}

/// What should be done to apply new filter to a set of data.
enum FilteringTask {
  /// New filter is equivalent to previous, so nothing should be done.
  doNothing,

  /// Previous filtering results cannot be reused.
  refilter,

  /// Previous filtering results can be reused.
  reuse,
}

class ClassFilter {
  ClassFilter({
    required this.filterType,
    required String except,
    required String? only,
  })  : except = _trimByLine(except),
        only = only == null ? null : _trimByLine(only);

  ClassFilter.empty()
      : this(
          filterType: ClassFilterType.all,
          except: standardLibrariesAlias,
          only: null,
        );

  static String _trimByLine(String value) =>
      value.split('\n').map((e) => e.trim()).join('\n');

  static const String standardLibrariesAlias = '\$standard-libraries';

  final ClassFilterType filterType;
  final String except;

  /// If the value is null, it should be initialized before displaying.
  final String? only;

  bool get isEmpty =>
      filterType == ClassFilterType.all ||
      (filterType == ClassFilterType.except && except.trim().isEmpty) ||
      (filterType == ClassFilterType.only && (only ?? '').trim().isEmpty);

  String get buttonTooltip {
    if (isEmpty) return 'Filter classes and packages.';
    return displayString;
  }

  bool equals(ClassFilter value) {
    return value.filterType == filterType &&
        value.except == except &&
        value.only == only;
  }

  Set<String> _filtersAsSet() {
    Set<String> stringToSet(String? s) =>
        s == null ? {} : s.split('\n').where((e) => e.isNotEmpty).toSet();

    switch (filterType) {
      case ClassFilterType.all:
        return {};
      case ClassFilterType.except:
        return stringToSet(except);
      case ClassFilterType.only:
        return stringToSet(only);
    }
  }

  late final Set<String> filters = _filtersAsSet();

  /// Task to be applied when filter changed.
  FilteringTask task({required ClassFilter? previous}) {
    if (previous == null) return FilteringTask.refilter;

    if (filterType == previous.filterType && filters == previous.filters) {
      return FilteringTask.doNothing;
    }

    if (filterType == ClassFilterType.only &&
        previous.filterType == ClassFilterType.only &&
        previous.filters.containsAll(filters)) {
      return FilteringTask.reuse;
    }

    if (filterType == ClassFilterType.except &&
        previous.filterType == ClassFilterType.except &&
        filters.containsAll(previous.filters)) {
      return FilteringTask.reuse;
    }

    return FilteringTask.refilter;
  }

  String get displayString {
    switch (filterType) {
      case ClassFilterType.all:
        return 'Show all classes.';
      case ClassFilterType.except:
        return 'Show all classes, except:\n$except';
      case ClassFilterType.only:
        return 'Show only:\n$only';
    }
  }

  bool apply(HeapClassName className) {
    if (filterType == ClassFilterType.all) return true;

    for (var filter in filters) {
      if (_isMatch(className, filter)) {
        return filterType == ClassFilterType.only;
      }
    }

    return filterType == ClassFilterType.except;
  }

  bool _isMatch(HeapClassName className, String filter) {
    if (className.fullName.contains(filter)) return true;
    if (filter == standardLibrariesAlias && className.isStandard) return true;
    return false;
  }
}
