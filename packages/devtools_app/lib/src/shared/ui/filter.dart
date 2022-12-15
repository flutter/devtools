// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../dialogs.dart';
import '../primitives/auto_dispose.dart';
import '../primitives/utils.dart';
import '../theme.dart';

// TODO(kenz): consider breaking this up flat data filtering and tree data
// filtering.
mixin FilterControllerMixin<T> {
  final filteredData = ListValueNotifier<T>([]);

  final activeFilter = ValueNotifier<Filter<T>?>(null);

  // TODO(kenz): refactor this so that `filterData` returns the filtered data
  // and does not have side effects other than filtering data. Add a
  // `onFilterApplied` method here that can be overridden to apply those
  // screen-specific side effects of filtering.
  void filterData(Filter<T> filter);

  void resetFilter() {
    // TODO(kenz): should we reset the activeFilter before setting to null?
    activeFilter.value = null;
  }
}

class FilterDialog<FilterControllerMixin, T> extends StatefulWidget {
  FilterDialog({
    required this.controller,
    this.onCancel,
    this.includeQueryFilter = true,
    this.queryInstructions,
    this.queryFilterArguments,
    this.toggleFilters,
    double? dialogWidth,
  })  : assert(
          !includeQueryFilter ||
              (queryInstructions != null && queryFilterArguments != null),
        ),
        dialogWidth = dialogWidth ?? defaultDialogWidth;

  final FilterControllerMixin controller;

  final VoidCallback? onCancel;

  final String? queryInstructions;

  final Map<String, QueryFilterArgument>? queryFilterArguments;

  final List<ToggleFilter<T>>? toggleFilters;

  final bool includeQueryFilter;

  final double dialogWidth;

  @override
  _FilterDialogState<T> createState() => _FilterDialogState<T>();
}

class _FilterDialogState<T>
    extends State<FilterDialog<FilterControllerMixin, T>>
    with AutoDisposeMixin {
  late final TextEditingController queryTextFieldController;

  @override
  void initState() {
    super.initState();
    queryTextFieldController = TextEditingController(
      text: widget.controller.activeFilter.value?.queryFilter?.query ?? '',
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
      helpText: widget.queryInstructions,
      onApply: () => widget.controller.filterData(
        Filter<T>(
          queryFilter: widget.includeQueryFilter
              ? QueryFilter.parse(
                  queryTextFieldController.value.text,
                  widget.queryFilterArguments!,
                )
              : null,
          toggleFilters: widget.toggleFilters,
        ),
      ),
      onCancel: widget.onCancel,
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
          ],
          if (widget.toggleFilters != null)
            for (final toggleFilter in widget.toggleFilters!) ...[
              ToggleFilterElement(filter: toggleFilter),
            ],
        ],
      ),
    );
  }

  void _resetFilters() {
    queryTextFieldController.clear();
    for (final toggleFilter in widget.toggleFilters ?? []) {
      toggleFilter.enabled.value = toggleFilter.enabledByDefault;
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
  const Filter({
    this.queryFilter,
    this.toggleFilters = const [],
  });

  final QueryFilter? queryFilter;

  final List<ToggleFilter<T>>? toggleFilters;
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
  QueryFilter({
    required this.filterArguments,
    this.substrings = const [],
  });

  factory QueryFilter.parse(
    String query,
    Map<String, QueryFilterArgument> args,
  ) {
    // Reset all argument values before generating a new QueryFilter.
    for (final arg in args.values) {
      arg.reset();
    }

    final partsBySpace = query.split(' ');
    final substrings = <String>[];
    for (final part in partsBySpace) {
      final querySeparatorIndex = part.indexOf(':');
      if (querySeparatorIndex != -1) {
        final value = part.substring(querySeparatorIndex + 1);
        if (value != '') {
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
    return QueryFilter(filterArguments: args, substrings: substrings);
  }

  final Map<String, QueryFilterArgument> filterArguments;

  final List<String> substrings;

  String get query => [
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
      final lowerCaseFilterValue = value.toLowerCase();
      matches = substringMatch
          ? dataValue.contains(lowerCaseFilterValue)
          : dataValue == lowerCaseFilterValue;
      if (matches) break;
    }
    return isNegative ? !matches : matches;
  }

  void reset() {
    values = [];
    isNegative = false;
  }
}
