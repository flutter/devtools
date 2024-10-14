// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:codicon/codicon.dart';
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
/// [createSettingFilters] and [createQueryFilterArgs].
///
/// Classes mixing in [FilterControllerMixin] must also extend
/// [DisposableController] and mixin [AutoDisposeControllerMixin], and a class
/// can subscribe to updates to the active filter by calling
/// [subscribeToFilterChanges].
mixin FilterControllerMixin<T> on DisposableController
    implements AutoDisposeControllerMixin {
  static const filterTagSeparator = '-#-';

  final filteredData = ListValueNotifier<T>([]);

  final useRegExp = ValueNotifier<bool>(false);

  ValueListenable<Filter<T>> get activeFilter => _activeFilter;

  late final _activeFilter = ValueNotifier<Filter<T>>(
    Filter(
      queryFilter: QueryFilter.empty(args: _queryFilterArgs),
      settingFilters: _settingFilters,
    ),
  );

  void setActiveFilter({
    String? query,
    List<SettingFilter<T, Object>>? settingFilters,
  }) {
    _activeFilter.value = Filter(
      queryFilter: query != null
          ? QueryFilter.parse(
              query,
              args: _queryFilterArgs,
              useRegExp: useRegExp.value,
            )
          : QueryFilter.empty(args: _queryFilterArgs),
      settingFilters: settingFilters ?? _settingFilters,
    );
  }

  void subscribeToFilterChanges() {
    addAutoDisposeListener(activeFilter, () {
      filterData(activeFilter.value);
    });
  }

  late final List<SettingFilter<T, Object>> _settingFilters =
      createSettingFilters();

  List<SettingFilter<T, Object>> createSettingFilters() => [];

  late final _queryFilterArgs = createQueryFilterArgs();

  Map<String, QueryFilterArgument> createQueryFilterArgs() =>
      <String, QueryFilterArgument>{};

  bool get isFilterActive {
    final filter = activeFilter.value;
    final queryFilterActive = !filter.queryFilter.isEmpty;
    final settingFilterActive =
        filter.settingFilters.any((filter) => filter.enabled);
    return queryFilterActive || settingFilterActive;
  }

  // TODO(kenz): de-dupe the filtering logic in overrides of this method.
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
    final suffixList = activeFilter.settingFilters
        .where((f) => f.enabled)
        .map((f) => '${f.name}:${f.setting.value}');

    final settingFilterTag = suffixList.join(',');
    final queryFilterTag = activeFilter.queryFilter.query.toLowerCase();
    return [
      settingFilterTag,
      queryFilterTag,
      if (queryFilterTag.isNotEmpty && useRegExp.value) 'regexp',
    ].where((e) => e.isNotEmpty).join(filterTagSeparator);
  }

  void _resetToDefaultFilter() {
    // Reset all filter values.
    for (final settingFilter in _settingFilters) {
      settingFilter.setting.value = settingFilter.defaultValue;
    }
    _queryFilterArgs.forEach((key, value) => value.reset());
  }

  void resetFilter() {
    _resetToDefaultFilter();
    _activeFilter.value = Filter(
      queryFilter: QueryFilter.empty(args: _queryFilterArgs),
      settingFilters: _settingFilters,
    );
  }
}

/// Dialog to manage filter settings.
///
/// This dialog interacts with a [FilterControllerMixin] to manage and preserve
/// the filter state.
class FilterDialog<T> extends StatefulWidget {
  FilterDialog({
    super.key,
    required this.controller,
    this.includeQueryFilter = true,
    this.queryInstructions,
  })  : assert(
          !includeQueryFilter ||
              (queryInstructions != null &&
                  controller._queryFilterArgs.isNotEmpty),
        ),
        settingFilterValuesAtOpen = List.generate(
          controller.activeFilter.value.settingFilters.length,
          (index) =>
              controller.activeFilter.value.settingFilters[index].setting.value,
        );

  final FilterControllerMixin<T> controller;

  final String? queryInstructions;

  final bool includeQueryFilter;

  final List<Object> settingFilterValuesAtOpen;

  @override
  State<FilterDialog<T>> createState() => _FilterDialogState<T>();
}

class _FilterDialogState<T> extends State<FilterDialog<T>>
    with AutoDisposeMixin {
  late final TextEditingController queryTextFieldController;
  late bool useRegExp;
  late bool pendingUseRegExp;

  @override
  void initState() {
    super.initState();
    queryTextFieldController = TextEditingController(
      text: widget.controller.activeFilter.value.queryFilter.query,
    );
    useRegExp = widget.controller.useRegExp.value;
    addAutoDisposeListener(widget.controller.useRegExp, () {
      useRegExp = widget.controller.useRegExp.value;
    });
    pendingUseRegExp = useRegExp;
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
              additionalSuffixActions: [
                DevToolsToggleButton(
                  icon: Codicons.regex,
                  message: 'Use regular expressions',
                  outlined: false,
                  isSelected: pendingUseRegExp,
                  onPressed: () => setState(() {
                    pendingUseRegExp = !pendingUseRegExp;
                  }),
                ),
              ],
            ),
            const SizedBox(height: defaultSpacing),
            if (widget.queryInstructions != null) ...[
              DialogHelpText(helpText: widget.queryInstructions!),
              const SizedBox(height: defaultSpacing),
            ],
          ],
          for (final filter in widget.controller._settingFilters) ...[
            if (filter is ToggleFilter<T>)
              _ToggleFilterElement(filter: filter)
            else
              _SettingFilterElement(filter: filter),
          ],
        ],
      ),
    );
  }

  void _applyFilterChanges() {
    widget.controller
      ..useRegExp.value = pendingUseRegExp
      ..setActiveFilter(
        query: widget.includeQueryFilter
            ? queryTextFieldController.value.text
            : null,
        settingFilters: widget.controller._settingFilters,
      );
  }

  void _resetFilters() {
    queryTextFieldController.clear();
    widget.controller._resetToDefaultFilter();
  }

  void _restoreOldValues() {
    for (var i = 0; i < widget.controller._settingFilters.length; i++) {
      final filter = widget.controller._settingFilters[i];
      filter.setting.value = widget.settingFilterValuesAtOpen[i];
    }
  }
}

class _ToggleFilterElement extends StatelessWidget {
  const _ToggleFilterElement({required this.filter});

  final ToggleFilter filter;

  @override
  Widget build(BuildContext context) {
    Widget content = InkWell(
      onTap: () => filter.setting.value = !filter.setting.value,
      child: Row(
        children: [
          NotifierCheckbox(notifier: filter.setting),
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

class _SettingFilterElement extends StatelessWidget {
  const _SettingFilterElement({required this.filter});

  final SettingFilter filter;

  static const _leadingInset = 6.0;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      // This padding is required to left-align [_SettingFilterElement]s with
      // [_ToggleFilterElement] checkboxes in the dialog.
      padding: const EdgeInsets.only(left: _leadingInset),
      child: Row(
        children: [
          Text(filter.name),
          const BulletSpacer(),
          ValueListenableBuilder(
            valueListenable: filter.setting,
            builder: (context, value, _) {
              return RoundedDropDownButton(
                value: value,
                items: filter.possibleValues
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => filter.setting.value = value!,
              );
            },
          ),
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
  Filter({required this.queryFilter, required this.settingFilters});

  final QueryFilter queryFilter;

  final List<SettingFilter<T, Object>> settingFilters;

  bool get isEmpty => queryFilter.isEmpty && settingFilters.isEmpty;
}

/// A boolean setting filter that can only be set to the value of true or false.
class ToggleFilter<T> extends SettingFilter<T, bool> {
  ToggleFilter({
    required super.name,
    required bool Function(T element) includeCallback,
    required super.defaultValue,
    super.tooltip,
  }) : super(
          possibleValues: [true, false],
          includeCallback: (T element, bool _) => includeCallback(element),
          enabledCallback: (bool filterValue) => filterValue,
        );
}

/// A filter setting that can be set to any of the predefined values
/// [possibleValues].
class SettingFilter<T, V> {
  SettingFilter({
    required this.name,
    required bool Function(T element, V currentFilterValue) includeCallback,
    required bool Function(V filterValue) enabledCallback,
    required this.possibleValues,
    required this.defaultValue,
    this.tooltip,
  })  : _includeCallback = includeCallback,
        _enabledCallback = enabledCallback,
        setting = ValueNotifier<V>(defaultValue),
        assert(possibleValues.contains(defaultValue));

  /// The name of this setting filter.
  final String name;

  /// The set of possible values that [setting] can be set to.
  final List<V> possibleValues;

  /// The default value of the filter.
  ///
  /// This will be used to set the initial [setting] of the filter, and may be set
  /// again later if the user triggers "reset to default" behavior from the
  /// filter dialog or from some other source.
  final V defaultValue;

  /// The current value of this setting filter.
  ///
  /// Filter dialogs and other filter affordances will read this value and
  /// listen to this notifier for changes.
  final ValueNotifier<V> setting;

  /// The tooltip to describe the setting filter.
  final String? tooltip;

  /// The callback that determines whether a data element should be included
  /// based on the filter criteria.
  final bool Function(T element, V currentFilterValue) _includeCallback;

  /// The callback that determines whether this filter is enabled based on the
  /// current value of the filter.
  final bool Function(V filterValue) _enabledCallback;

  /// Whether a data element should be included based on the current state of the
  /// filter.
  bool includeData(T data) {
    return !enabled || _includeCallback(data, setting.value);
  }

  /// Whether this filter is enabled based on the current value of the filter.
  bool get enabled => _enabledCallback(setting.value);
}

class QueryFilter {
  const QueryFilter._({
    this.filterArguments = const <String, QueryFilterArgument>{},
    this.substringExpressions = const <Pattern>[],
    this.isEmpty = false,
  });

  factory QueryFilter.empty({required Map<String, QueryFilterArgument> args}) {
    return QueryFilter._(
      filterArguments: args,
      substringExpressions: <Pattern>[],
      isEmpty: true,
    );
  }

  factory QueryFilter.parse(
    String query, {
    required Map<String, QueryFilterArgument> args,
    required bool useRegExp,
  }) {
    if (query.isEmpty) {
      return QueryFilter.empty(args: args);
    }

    // Reset all argument values before generating a new QueryFilter.
    for (final arg in args.values) {
      arg.reset();
    }

    final partsBySpace = query.split(' ');
    final substringExpressions = <Pattern>[];
    for (final part in partsBySpace) {
      final querySeparatorIndex = part.indexOf(':');
      if (querySeparatorIndex != -1) {
        final value = part.substring(querySeparatorIndex + 1).trim();
        if (value.isNotEmpty) {
          for (final arg in args.values) {
            if (arg.matchesKey(part)) {
              arg.isNegative =
                  part.startsWith(QueryFilterArgument.negativePrefix);
              final valueStrings =
                  value.split(QueryFilterArgument.valueSeparator);
              arg.values = useRegExp
                  ? valueStrings
                      .map((v) => RegExp(v, caseSensitive: false))
                      .toList()
                  : valueStrings;
            }
          }
        }
      } else {
        substringExpressions
            .add(useRegExp ? RegExp(part, caseSensitive: false) : part);
      }
    }

    bool validArgumentFilter = false;
    for (final arg in args.values) {
      if (arg.values.isNotEmpty) {
        validArgumentFilter = true;
        break;
      }
    }
    if (!validArgumentFilter && substringExpressions.isEmpty) {
      return QueryFilter.empty(args: args);
    }

    return QueryFilter._(
      filterArguments: args,
      substringExpressions: substringExpressions,
    );
  }

  final Map<String, QueryFilterArgument> filterArguments;

  final List<Pattern> substringExpressions;

  final bool isEmpty;

  String get query => isEmpty
      ? ''
      : [
          ...substringExpressions.toStringList(),
          for (final arg in filterArguments.values) arg.display,
        ].join(' ').trim();
}

class QueryFilterArgument<T> {
  QueryFilterArgument({
    required this.keys,
    required this.dataValueProvider,
    required this.substringMatch,
    this.values = const [],
    this.isNegative = false,
  });

  static const negativePrefix = '-';

  static const valueSeparator = ',';

  final List<String> keys;

  final String? Function(T data) dataValueProvider;

  final bool substringMatch;

  List<Pattern> values;

  bool isNegative;

  String get display {
    if (values.isEmpty) return '';
    return '${isNegative ? negativePrefix : ''}${keys.first}:'
        '${values.toStringList().join(valueSeparator)}';
  }

  bool matchesKey(String query) {
    for (final key in keys) {
      if (query.startsWith('$key:') || query.startsWith('-$key:')) return true;
    }
    return false;
  }

  bool matchesValue(T data) {
    // If there are no specified filter values, consider [dataValue] to match
    // this filter.
    if (values.isEmpty) return true;

    final dataValue = dataValueProvider(data);
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

extension PatternListExtension on List<Pattern> {
  List<String> toStringList() {
    return safeFirst is RegExp
        ? cast<RegExp>().map((v) => v.pattern).toList()
        : cast<String>();
  }
}

// TODO:: Change screens that use [DevtoolsFilterButton] to use a [StandaloneFilterField]
// instead.
/// A text field for controlling the filter query for a [FilterControllerMixin].
///
/// This text field has a button to open a dialog for toggling any toggleable
/// text filters.
class StandaloneFilterField<T> extends StatefulWidget {
  const StandaloneFilterField({
    super.key,
    required this.controller,
  });

  final FilterControllerMixin<T> controller;

  @override
  State<StandaloneFilterField<T>> createState() =>
      _StandaloneFilterFieldState<T>();
}

class _StandaloneFilterFieldState<T> extends State<StandaloneFilterField<T>>
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
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.controller.useRegExp,
            builder: (context, useRegExp, _) {
              return DevToolsClearableTextField(
                autofocus: true,
                hintText: 'Filter',
                controller: queryTextFieldController,
                prefixIcon: Container(
                  height: inputDecorationElementHeight,
                  padding: const EdgeInsets.only(
                    left: densePadding,
                    right: denseSpacing,
                  ),
                  child: ValueListenableBuilder<Filter>(
                    valueListenable: widget.controller.activeFilter,
                    builder: (context, _, __) {
                      // TODO(https://github.com/flutter/devtools/issues/8426): support filtering by log level.
                      return DevToolsFilterButton(
                        message: 'More filters',
                        onPressed: () {
                          unawaited(
                            showDialog(
                              context: context,
                              builder: (context) => FilterDialog(
                                controller: widget.controller,
                                includeQueryFilter: false,
                              ),
                            ),
                          );
                        },
                        isFilterActive: widget.controller.isFilterActive,
                      );
                    },
                  ),
                ),
                additionalSuffixActions: [
                  DevToolsToggleButton(
                    icon: Codicons.regex,
                    message: 'Use regular expressions',
                    outlined: false,
                    isSelected: useRegExp,
                    onPressed: () {
                      widget.controller.useRegExp.value = !useRegExp;
                      widget.controller.setActiveFilter(
                        query: queryTextFieldController.value.text,
                        settingFilters: widget.controller._settingFilters,
                      );
                    },
                  ),
                ],
                onChanged: (_) {
                  widget.controller.setActiveFilter(
                    query: queryTextFieldController.value.text,
                    settingFilters: widget.controller._settingFilters,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
