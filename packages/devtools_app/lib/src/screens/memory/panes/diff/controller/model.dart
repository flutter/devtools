// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ClassFilterType {
  all,
  except,
  only,
}

enum FilteringTask {
  doNothing,
  reFilter,
  reUse,
}

class ClassFilter {
  ClassFilter({
    required this.filterType,
    required this.except,
    required this.only,
  });

  ClassFilter.empty()
      : this(
          filterType: ClassFilterType.all,
          except: standardLibrariesAlias,
          only: '',
        );

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

  FilteringTask task(ClassFilter previousFilter) {
    if (filterType == previousFilter.filterType &&
        filters == previousFilter.filters) {
      return FilteringTask.doNothing;
    }

    if (filterType == ClassFilterType.only &&
        previousFilter.filterType == ClassFilterType.only &&
        filters.startsWith(previousFilter.filters)) {
      return FilteringTask.reUse;
    }

    if (filterType == ClassFilterType.except &&
        previousFilter.filterType == ClassFilterType.except &&
        filters.startsWith(previousFilter.filters)) {
      return FilteringTask.reUse;
    }

    return FilteringTask.reFilter;
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
