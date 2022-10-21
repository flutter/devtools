// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ClassFilterType {
  all,
  except,
  only,
}

/// What should be done to apply new filter.
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
    required String only,
  })  : except = _trimByLine(except),
        only = _trimByLine(only);

  ClassFilter.empty()
      : this(
          filterType: ClassFilterType.all,
          except: standardLibrariesAlias,
          only: '',
        );

  static String _trimByLine(String value) =>
      value.split('\n').map((e) => e.trim()).join('\n');

  static const String standardLibrariesAlias = 'standard-libraries';

  final ClassFilterType filterType;
  final String except;
  final String only;

  bool get isEmpty =>
      filterType == ClassFilterType.all ||
      (filterType == ClassFilterType.except && except.trim().isEmpty) ||
      (filterType == ClassFilterType.only && only.trim().isEmpty);

  String get buttonTooltip {
    if (isEmpty) return 'Filter classes and packages.';
    return displayString;
  }

  bool equals(ClassFilter value) {
    return value.filterType == filterType &&
        value.except == except &&
        value.only == only;
  }

  String get filters {
    switch (filterType) {
      case ClassFilterType.all:
        return '';
      case ClassFilterType.except:
        return except;
      case ClassFilterType.only:
        return only;
    }
  }

  FilteringTask task({required ClassFilter previous}) {
    if (filterType == previous.filterType && filters == previous.filters) {
      return FilteringTask.doNothing;
    }

    if (filterType == ClassFilterType.only &&
        previous.filterType == ClassFilterType.only &&
        previous.filters.startsWith(filters)) {
      return FilteringTask.reuse;
    }

    if (filterType == ClassFilterType.except &&
        previous.filterType == ClassFilterType.except &&
        filters.startsWith(previous.filters)) {
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
}
