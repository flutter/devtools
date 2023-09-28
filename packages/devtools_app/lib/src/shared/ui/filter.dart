// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../primitives/utils.dart';

// TODO(kenz): consider breaking this up for flat data filtering and tree data
// filtering.

/// Mixin to add to feature controllers that need to support filtering data and
/// storing the state of those filters.
///
/// To use this mixin, you must implement [filterData] as well as either or both
/// [createToggleFilters] and [createQueryFilterArgs].
///
/// Classes mixing in [FilterControllerMixin] must also extend
/// [DisposableController] and mixin [AutoDisposeControllerMixin], and a class
/// can subscribe to updates to the active filter by calling
/// [subscribeToFilterChanges].
mixin FilterControllerMixin<T> on DisposableController
    implements AutoDisposeControllerMixin {
  static const filterTagSeparator = '-#-';

  final filteredData = ListValueNotifier<T>([]);

  // TODO(kenz): replace [Filter] class with a record when available.
  ValueListenable<Filter<T>> get activeFilter => _activeFilter;

  late final _activeFilter = ValueNotifier<Filter<T>>(
    Filter(
      queryFilter: QueryFilter.empty(args: _queryFilterArgs),
      toggleFilters: _toggleFilters,
    ),
  );

  void setActiveFilter({
    String? query,
    List<ToggleFilter<T>>? toggleFilters,
  }) {
    _activeFilter.value = Filter(
      queryFilter: query != null
          ? QueryFilter.parse(query, args: _queryFilterArgs)
          : QueryFilter.empty(args: _queryFilterArgs),
      toggleFilters: toggleFilters ?? _toggleFilters,
    );
  }

  void subscribeToFilterChanges() {
    addAutoDisposeListener(activeFilter, () {
      filterData(activeFilter.value);
    });
  }

  late final List<ToggleFilter<T>> _toggleFilters = createToggleFilters();

  List<ToggleFilter<T>> createToggleFilters() => [];

  late final Map<String, QueryFilterArgument> _queryFilterArgs =
      createQueryFilterArgs();

  Map<String, QueryFilterArgument> createQueryFilterArgs() => {};

  bool get isFilterActive {
    final filter = activeFilter.value;
    final queryFilterActive = !filter.queryFilter.isEmpty;
    final toggleFilterActive = filter.toggleFilters.any(
      (filter) => filter.enabled.value,
    );
    return queryFilterActive || toggleFilterActive;
  }

  // TODO(kenz): refactor this so that `filterData` returns the filtered data
  // and does not have side effects other than filtering data. Add a
  // `onFilterApplied` method here that can be overridden to apply those
  // screen-specific side effects of filtering. This will require us to
  // split up tree filtering and flat table filtering though.
  @mustCallSuper
  void filterData(Filter<T> filter) {
    _activeFilter.value = filter;
  }

  String activeFilterTag() {
    final activeFilter = _activeFilter.value;
    final suffixList = <String>[];
    for (final toggleFilter in activeFilter.toggleFilters) {
      if (toggleFilter.enabled.value) {
        suffixList.add(toggleFilter.name);
      }
    }
    final toggleFilterTag = suffixList.join(',');
    final queryFilterTag = activeFilter.queryFilter.query.toLowerCase();
    return [toggleFilterTag, queryFilterTag]
        .where((e) => e.isNotEmpty)
        .join(filterTagSeparator);
  }

  void _resetToDefaultFilter() {
    // Reset all filter values.
    for (final toggleFilter in _toggleFilters) {
      toggleFilter.enabled.value = toggleFilter.enabledByDefault;
    }
    _queryFilterArgs.forEach((key, value) => value.reset());
  }

  void resetFilter() {
    _resetToDefaultFilter();
    _activeFilter.value = Filter(
      queryFilter: QueryFilter.empty(args: _queryFilterArgs),
      toggleFilters: _toggleFilters,
    );
  }
}

/// Dialog to manage filter settings.
///
/// This dialog interacts with a [FilterControllerMixin] to manage and preserve
/// the filter state managed by the dialog.
class FilterDialog<T> extends StatefulWidget {
  FilterDialog({
    super.key,
    required this.controller,
    this.includeQueryFilter = true,
    this.queryInstructions,
    double? dialogWidth,
  })  : assert(
          !includeQueryFilter ||
              (queryInstructions != null &&
                  controller._queryFilterArgs.isNotEmpty),
        ),
        dialogWidth = dialogWidth ?? defaultDialogWidth,
        toggleFilterValuesAtOpen = List.generate(
          controller.activeFilter.value.toggleFilters.length,
          (index) =>
              controller.activeFilter.value.toggleFilters[index].enabled.value,
        );

  final FilterControllerMixin<T> controller;

  final String? queryInstructions;

  final bool includeQueryFilter;

  final double dialogWidth;

  final List<bool> toggleFilterValuesAtOpen;

  @override
  State<FilterDialog<T>> createState() => _FilterDialogState<T>();
}

class _FilterDialogState<T> extends State<FilterDialog<T>>
    with AutoDisposeMixin {
  late final TextEditingController queryTextFieldController;

  @override
  void initState() {
    super.initState();
    queryTextFieldController = TextEditingController(
      text: widget.controller.activeFilter.value.queryFilter.query,
    );
  }

  @override
  void dispose() {
    queryTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StateUpdateDialog(
      title: 'Filters',
      onApply: _applyFilterChanges,
      onCancel: _restoreOldValues,
      onResetDefaults: _resetFilters,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.includeQueryFilter) ...[
            DevToolsClearableTextField(
              autofocus: true,
              labelText: 'Filter Query',
              controller: queryTextFieldController,
            ),
            const SizedBox(height: defaultSpacing),
            if (widget.queryInstructions != null) ...[
              DialogHelpText(helpText: widget.queryInstructions!),
              const SizedBox(height: defaultSpacing),
            ],
          ],
          for (final toggleFilter in widget.controller._toggleFilters) ...[
            ToggleFilterElement(filter: toggleFilter),
          ],
        ],
      ),
    );
  }

  void _applyFilterChanges() {
    widget.controller.setActiveFilter(
      query: widget.includeQueryFilter
          ? queryTextFieldController.value.text
          : null,
      toggleFilters: widget.controller._toggleFilters,
    );
  }

  void _resetFilters() {
    queryTextFieldController.clear();
    widget.controller._resetToDefaultFilter();
  }

  void _restoreOldValues() {
    for (var i = 0; i < widget.controller._toggleFilters.length; i++) {
      final filter = widget.controller._toggleFilters[i];
      filter.enabled.value = widget.toggleFilterValuesAtOpen[i];
    }
  }
}

class ToggleFilterElement extends StatelessWidget {
  const ToggleFilterElement({Key? key, required this.filter}) : super(key: key);

  final ToggleFilter filter;

  @override
  Widget build(BuildContext context) {
    Widget content = InkWell(
      onTap: () => filter.enabled.value = !filter.enabled.value,
      child: Row(
        children: [
          NotifierCheckbox(notifier: filter.enabled),
          Text(filter.name),
        ],
      ),
    );
    if (filter.tooltip != null) {
      content = DevToolsTooltip(
        message: filter.tooltip,
        child: content,
      );
    }
    return content;
  }
}

class Filter<T> {
  Filter({required this.queryFilter, required this.toggleFilters});

  final QueryFilter queryFilter;

  final List<ToggleFilter<T>> toggleFilters;

  bool get isEmpty => queryFilter.isEmpty && toggleFilters.isEmpty;
}

class ToggleFilter<T> {
  ToggleFilter({
    required this.name,
    required this.includeCallback,
    this.tooltip,
    this.enabledByDefault = false,
  }) : enabled = ValueNotifier<bool>(enabledByDefault);

  final String name;

  final bool Function(T element) includeCallback;

  final String? tooltip;

  final bool enabledByDefault;

  final ValueNotifier<bool> enabled;
}

class QueryFilter {
  const QueryFilter._({
    this.filterArguments = const <String, QueryFilterArgument>{},
    this.substrings = const [],
    this.isEmpty = false,
  });

  factory QueryFilter.empty({required Map<String, QueryFilterArgument> args}) {
    return QueryFilter._(
      filterArguments: args,
      substrings: <String>[],
      isEmpty: true,
    );
  }

  factory QueryFilter.parse(
    String query, {
    required Map<String, QueryFilterArgument> args,
  }) {
    if (query.isEmpty) {
      return QueryFilter.empty(args: args);
    }

    // Reset all argument values before generating a new QueryFilter.
    for (final arg in args.values) {
      arg.reset();
    }

    final partsBySpace = query.split(' ');
    final substrings = <String>[];
    for (final part in partsBySpace) {
      final querySeparatorIndex = part.indexOf(':');
      if (querySeparatorIndex != -1) {
        final value = part.substring(querySeparatorIndex + 1).trim();
        if (value.isNotEmpty) {
          for (var arg in args.values) {
            if (arg.matchesKey(part)) {
              arg.isNegative =
                  part.startsWith(QueryFilterArgument.negativePrefix);
              arg.values = value.split(QueryFilterArgument.valueSeparator);
            }
          }
        }
      } else {
        substrings.add(part);
      }
    }

    bool validArgumentFilter = false;
    for (final arg in args.values) {
      if (arg.values.isNotEmpty) {
        validArgumentFilter = true;
        break;
      }
    }
    if (!validArgumentFilter && substrings.isEmpty) {
      return QueryFilter.empty(args: args);
    }

    return QueryFilter._(
      filterArguments: args,
      substrings: substrings,
    );
  }

  final Map<String, QueryFilterArgument> filterArguments;

  final List<String> substrings;

  final bool isEmpty;

  String get query => isEmpty
      ? ''
      : [
          ...substrings,
          for (final arg in filterArguments.values) arg.display,
        ].join(' ').trim();
}

class QueryFilterArgument {
  QueryFilterArgument({
    required this.keys,
    this.values = const [],
    this.isNegative = false,
  });

  static const negativePrefix = '-';

  static const valueSeparator = ',';

  final List<String> keys;

  List<String> values;

  bool isNegative;

  bool get isNotEmpty => values.isNotEmpty;

  String get display => values.isNotEmpty
      ? '${isNegative ? negativePrefix : ''}${keys.first}:${values.join(valueSeparator)}'
      : '';

  bool matchesKey(String query) {
    for (final key in keys) {
      if (query.startsWith('$key:') || query.startsWith('-$key:')) return true;
    }
    return false;
  }

  bool matchesValue(String? dataValue, {bool substringMatch = false}) {
    // If there are no specified filter values, consider [dataValue] to match
    // this filter.
    if (values.isEmpty) return true;

    if (dataValue == null) {
      return isNegative;
    }

    var matches = false;
    for (final value in values) {
      matches = substringMatch
          ? dataValue.caseInsensitiveContains(value)
          : dataValue.caseInsensitiveEquals(value);
      if (matches) break;
    }
    return isNegative ? !matches : matches;
  }

  void reset() {
    values = [];
    isNegative = false;
  }
}
