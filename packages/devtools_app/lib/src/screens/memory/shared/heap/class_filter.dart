// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../shared/globals.dart';
import '../../../../shared/memory/class_name.dart';

enum ClassFilterType {
  showAll,
  except,
  only,
}

class ClassFilterData {
  ClassFilterData({
    required this.filter,
    required this.onChanged,
  });

  final ValueListenable<ClassFilter> filter;
  final ApplyFilterCallback onChanged;
  late final String? rootPackage =
      serviceConnection.serviceManager.rootInfoNow().package;
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

typedef ApplyFilterCallback = void Function(ClassFilter);

@immutable
class ClassFilter {
  ClassFilter({
    required this.filterType,
    required String except,
    required String? only,
  })  : except = _trimByLine(except),
        only = only == null ? null : _trimByLine(only);

  ClassFilter.empty()
      : this(
          filterType: ClassFilterType.except,
          except: defaultExceptString,
          only: null,
        );

  @visibleForTesting
  static final defaultExceptString =
      '${ClassType.runtime.alias}\n${ClassType.sdk.alias}';

  static String _trimByLine(String value) =>
      value.split('\n').map((e) => e.trim()).join('\n');

  final ClassFilterType filterType;
  final String except;

  /// If the value is null, it should be initialized before displaying.
  final String? only;

  bool get isEmpty =>
      filterType == ClassFilterType.showAll ||
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
    Set<String> stringToSet(String? s) => s == null
        ? {}
        : s
            .split(RegExp(',|\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();

    switch (filterType) {
      case ClassFilterType.showAll:
        return {};
      case ClassFilterType.except:
        return stringToSet(except);
      case ClassFilterType.only:
        return stringToSet(only);
    }
  }

  late final Set<String> filters = _filtersAsSet();

  /// Task to be applied when filter changed.
  @visibleForTesting
  FilteringTask task({required ClassFilter? previous}) {
    if (previous == null) return FilteringTask.refilter;

    if (filterType == previous.filterType &&
        setEquals(filters, previous.filters)) {
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
      case ClassFilterType.showAll:
        return 'Show all classes';
      case ClassFilterType.except:
        return 'Show all classes, except:\n$except';
      case ClassFilterType.only:
        return 'Show only:\n$only';
    }
  }

  bool apply(HeapClassName className, String? rootPackage) {
    if (className.isRoot) return false;

    if (filterType == ClassFilterType.showAll) return true;

    for (var filter in filters) {
      if (_isMatch(className, filter, rootPackage)) {
        return filterType == ClassFilterType.only;
      }
    }

    return filterType == ClassFilterType.except;
  }

  /// Filters items in [original] by class with [newFilter].
  ///
  /// Utilizes previous filtering results, that are
  /// [oldFiltered] with [oldFilter], if possible.
  ///
  /// Uses [extractClass] to get class from an item in the list.
  ///
  /// Uses [rootPackage] to pass to filter for root package.
  /// alias replacement.
  static List<T> filter<T>({
    required ClassFilter? oldFilter,
    required List<T>? oldFiltered,
    required ClassFilter newFilter,
    required List<T> original,
    required HeapClassName Function(T) extractClass,
    required String? rootPackage,
  }) {
    if ((oldFilter == null) != (oldFiltered == null)) {
      throw StateError('Nullness should match.');
    }

    // Return previous data if filter did not change.
    if (oldFilter == newFilter) return oldFiltered!;

    // Return previous data if filter is identical.
    final task = newFilter.task(previous: oldFilter);
    if (task == FilteringTask.doNothing) return original;

    final Iterable<T> dataToFilter;
    if (task == FilteringTask.refilter) {
      dataToFilter = original;
    } else if (task == FilteringTask.reuse) {
      dataToFilter = oldFiltered!;
    } else {
      throw StateError('Unexpected task: $task.');
    }

    final result = dataToFilter
        .where((e) => newFilter.apply(extractClass(e), rootPackage))
        .toList();

    return result;
  }

  bool _isMatch(HeapClassName className, String filter, String? rootPackage) {
    if (className.fullName.contains(filter)) return true;

    final classType = className.classType(rootPackage);
    return filter == classType.alias;
  }
}
