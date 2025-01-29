// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../primitives/utils.dart';
import 'common_widgets.dart';

typedef QueryFilterArgs<T> = Map<String, QueryFilterArgument<T>>;
typedef SettingFilters<T> = List<SettingFilter<T, Object>>;

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
/// [initFilterController].
mixin FilterControllerMixin<T> on DisposableController
    implements AutoDisposeControllerMixin {
  final filteredData = ListValueNotifier<T>(<T>[]);

  final useRegExp = ValueNotifier<bool>(false);

  /// The notifier that stores the current filter tag in DevTools preferences.
  ///
  /// This should be overriden as a getter by subclasses to support persisting
  /// the most recent filter to DevTools preferences.
  ValueNotifier<String>? filterTagNotifier;

  ValueListenable<Filter<T>> get activeFilter => _activeFilter;

  late final _activeFilter = ValueNotifier<Filter<T>>(
    Filter(
      queryFilter: QueryFilter.empty(args: queryFilterArgs),
      settingFilters: settingFilters,
    ),
  );

  void setActiveFilter({String? query, SettingFilters<T>? settingFilters}) {
    _activeFilter.value = Filter(
      queryFilter:
          query != null
              ? QueryFilter.parse(
                query,
                args: queryFilterArgs,
                useRegExp: useRegExp.value,
              )
              : QueryFilter.empty(args: queryFilterArgs),
      settingFilters: settingFilters ?? this.settingFilters,
    );
  }

  void initFilterController() {
    if (filterTagNotifier != null) {
      final tag = FilterTag.parse(filterTagNotifier!.value);
      setFilterFromTag(tag);
    }
    addAutoDisposeListener(activeFilter, () {
      filterData(activeFilter.value);
      filterTagNotifier?.value = activeFilterTag();
    });
  }

  /// Creates the setting filters for this filter controller.
  ///
  /// This method should be overridden by subclasses to support filtering by
  /// settings (e.g. check box, dropdown selection, etc.).
  SettingFilters<T> createSettingFilters() => [];

  @visibleForTesting
  late final SettingFilters<T> settingFilters = createSettingFilters();

  /// Creates the query filter arguments for this filter controller.
  ///
  /// This method should be overridden by subclasses to support filtering by
  /// query arguments in addition to raw String matches. For example, a filter
  /// query with arguments may look like 'foo category:bar type:baz'. In this
  /// example, 'category' and 'type' would need to be defined as query filter
  /// arguments.
  QueryFilterArgs<T> createQueryFilterArgs() =>
      <String, QueryFilterArgument<T>>{};

  @visibleForTesting
  late final queryFilterArgs = createQueryFilterArgs();

  bool get isFilterActive {
    final filter = activeFilter.value;
    final queryFilterActive = !filter.queryFilter.isEmpty;
    final settingFilterActive = filter.settingFilters.any(
      (filter) => filter.enabled,
    );
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

  /// The filter tag as a String for the currently active filter.
  ///
  /// See also [FilterTag].
  String activeFilterTag() {
    final filter = _activeFilter.value;
    return FilterTag(
      query: filter.queryFilter.query,
      settingFilterValues:
          settingFilters.map((filter) => filter.valueAsJson).toList(),
      useRegExp: useRegExp.value,
    ).tag;
  }

  /// Sets the active filter state from the given [tag].
  ///
  /// See also [FilterTag].
  void setFilterFromTag(FilterTag? tag) {
    if (tag == null) return;

    useRegExp.value = tag.useRegExp;

    final valuesFromTag = tag.settingFilterValues.map((value) {
      assert(
        value.length == 1,
        'Each setting filter map should only have one entry.',
      );
      return (id: value.keys.first, value: value.values.first);
    });
    final settingFilterIds = settingFilters.map((filter) => filter.id);
    for (final settingFilterValue in valuesFromTag) {
      if (settingFilterIds.contains(settingFilterValue.id)) {
        final settingFilter = settingFilters.firstWhere(
          (filter) => filter.id == settingFilterValue.id,
        );
        settingFilter.setting.value = settingFilterValue.value!;
      }
    }

    setActiveFilter(query: tag.query, settingFilters: settingFilters);
  }

  void _resetToDefaultFilter() {
    // Reset all filter values.
    for (final settingFilter in settingFilters) {
      settingFilter.setting.value = settingFilter.defaultValue;
    }
    queryFilterArgs.forEach((key, value) => value.reset());
  }

  void resetFilter() {
    _resetToDefaultFilter();
    _activeFilter.value = Filter(
      queryFilter: QueryFilter.empty(args: queryFilterArgs),
      settingFilters: settingFilters,
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
    required this.filteredItem,
  }) : assert(controller.queryFilterArgs.isNotEmpty),
       settingFilterValuesAtOpen = List.generate(
         controller.activeFilter.value.settingFilters.length,
         (index) =>
             controller.activeFilter.value.settingFilters[index].setting.value,
       );

  final FilterControllerMixin<T> controller;

  final String filteredItem;

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
          for (final filter in widget.controller.settingFilters) ...[
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
        query: widget.controller.activeFilter.value.queryFilter.query,
        settingFilters: widget.controller.settingFilters,
      );
  }

  void _resetFilters() {
    queryTextFieldController.clear();
    widget.controller._resetToDefaultFilter();
  }

  void _restoreOldValues() {
    for (var i = 0; i < widget.controller.settingFilters.length; i++) {
      final filter = widget.controller.settingFilters[i];
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
      content = DevToolsTooltip(message: filter.tooltip, child: content);
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
                items: [
                  for (int i = 0; i < filter.possibleValues.length; i++)
                    DropdownMenuItem(
                      value: filter.possibleValues[i],
                      child: Text(
                        '${filter.possibleValueDisplays?[i] ?? filter.possibleValues[i]}',
                      ),
                    ),
                ],
                onChanged: (value) => filter.setting.value = value!,
              );
            },
          ),
        ],
      ),
    );
    if (filter.tooltip != null) {
      content = DevToolsTooltip(message: filter.tooltip, child: content);
    }
    return content;
  }
}

class Filter<T> {
  Filter({required this.queryFilter, required this.settingFilters});

  final QueryFilter queryFilter;

  final SettingFilters<T> settingFilters;

  bool get isEmpty => queryFilter.isEmpty && settingFilters.isEmpty;
}

/// A boolean setting filter that can only be set to the value of true or false.
class ToggleFilter<T> extends SettingFilter<T, bool> {
  ToggleFilter({
    required super.id,
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
///
/// The generic type [V] must be a json encodable type, since this value will
/// be JSON encoded and decoded during the creation and parsing of [FilterTag]
/// objects.
class SettingFilter<T, V> {
  SettingFilter({
    required this.id,
    required this.name,
    required bool Function(T element, V currentFilterValue) includeCallback,
    required bool Function(V filterValue) enabledCallback,
    required this.defaultValue,
    required this.possibleValues,
    this.possibleValueDisplays,
    this.tooltip,
  }) : _includeCallback = includeCallback,
       _enabledCallback = enabledCallback,
       setting = ValueNotifier<V>(defaultValue),
       assert(possibleValues.contains(defaultValue)),
       assert(
         possibleValueDisplays == null ||
             possibleValues.length == possibleValueDisplays.length,
       );

  /// The unique id for this setting filter.
  ///
  /// This value will be used when reading and writing setting filter values to
  /// DevTools preferences on disk.
  final String id;

  /// The name of this setting filter.
  final String name;

  /// The set of possible values that [setting] can be set to.
  final List<V> possibleValues;

  /// An optional List of values to use for the display of the setting filter
  /// options in a dropdown menu.
  ///
  /// If null, the String representation of each value in [possibleValues] will
  /// be used for the dropdown menu items instead.
  ///
  /// The length and order of this List should match that of [possibleValues].
  final List<String>? possibleValueDisplays;

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

  Map<String, Object?> get valueAsJson => {id: setting.value};
}

class QueryFilter {
  const QueryFilter._({
    this.filterArguments = const <String, QueryFilterArgument>{},
    this.substringExpressions = const <Pattern>[],
    this.isEmpty = false,
  });

  factory QueryFilter.empty({required QueryFilterArgs args}) {
    return QueryFilter._(
      filterArguments: args,
      substringExpressions: <Pattern>[],
      isEmpty: true,
    );
  }

  factory QueryFilter.parse(
    String query, {
    required QueryFilterArgs args,
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
              arg.isNegative = part.startsWith(
                QueryFilterArgument.negativePrefix,
              );
              final valueStrings = value.split(
                QueryFilterArgument.valueSeparator,
              );
              arg.values =
                  useRegExp
                      ? valueStrings
                          .map((v) => RegExp(v, caseSensitive: false))
                          .toList()
                      : valueStrings;
            }
          }
        }
      } else {
        substringExpressions.add(
          useRegExp ? RegExp(part, caseSensitive: false) : part,
        );
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

  final QueryFilterArgs filterArguments;

  final List<Pattern> substringExpressions;

  final bool isEmpty;

  String get query =>
      isEmpty
          ? ''
          : [
            ...substringExpressions.toStringList(),
            for (final arg in filterArguments.values) arg.display,
          ].join(' ').trim();
}

class QueryFilterArgument<T> {
  QueryFilterArgument({
    required this.keys,
    required this.exampleUsages,
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

  final List<String> exampleUsages;

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
      matches =
          substringMatch
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

/// A text field for controlling the filter query for a [FilterControllerMixin].
///
/// This text field has a button to open a dialog for toggling any toggleable
/// text filters.
class StandaloneFilterField<T> extends StatefulWidget {
  const StandaloneFilterField({
    super.key,
    required this.controller,
    required this.filteredItem,
  });

  final FilterControllerMixin<T> controller;

  final String filteredItem;

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
                prefixIcon:
                    widget.controller.settingFilters.isNotEmpty
                        ? Container(
                          height: inputDecorationElementHeight,
                          padding: const EdgeInsets.only(
                            left: densePadding,
                            right: denseSpacing,
                          ),
                          child: ValueListenableBuilder<Filter>(
                            valueListenable: widget.controller.activeFilter,
                            builder: (context, _, _) {
                              return DevToolsFilterButton(
                                message: 'More filters',
                                onPressed: () {
                                  unawaited(
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => FilterDialog(
                                            controller: widget.controller,
                                            filteredItem: widget.filteredItem,
                                          ),
                                    ),
                                  );
                                },
                                isFilterActive:
                                    widget.controller.isFilterActive,
                              );
                            },
                          ),
                        )
                        : null,
                additionalSuffixActions: [
                  if (widget.controller.queryFilterArgs.isNotEmpty)
                    InputDecorationSuffixButton.help(
                      onPressed: () {
                        showDevToolsDialog(
                          context: context,
                          title: 'Filter Syntax',
                          content: _FilterSyntax(
                            controller: widget.controller,
                            filteredItem: widget.filteredItem,
                          ),
                        );
                      },
                    ),
                  DevToolsToggleButton(
                    icon: Icons.emergency,
                    message: 'Use regular expressions',
                    outlined: false,
                    isSelected: useRegExp,
                    onPressed: () {
                      widget.controller.useRegExp.value = !useRegExp;
                      widget.controller.setActiveFilter(
                        query: queryTextFieldController.value.text,
                        settingFilters: widget.controller.settingFilters,
                      );
                    },
                  ),
                ],
                onChanged: (_) {
                  widget.controller.setActiveFilter(
                    query: queryTextFieldController.value.text,
                    settingFilters: widget.controller.settingFilters,
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

class _FilterSyntax<T> extends StatelessWidget {
  const _FilterSyntax({required this.controller, required this.filteredItem});

  final FilterControllerMixin<T> controller;
  final String filteredItem;

  static const _separator = ', ';

  @override
  Widget build(BuildContext context) {
    final queryFilterArgs = controller.queryFilterArgs.values;
    final filterKeys = queryFilterArgs.map(
      (arg) => arg.keys.map((key) => "'$key'").join(_separator),
    );
    final filterExampleUsages = queryFilterArgs.map(
      (arg) => arg.exampleUsages.map((usage) => "'$usage'").join(_separator),
    );

    final usageTextStyle = Theme.of(context).fixedFontStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('''
Type a query to show or hide specific ${pluralize(filteredItem, 2)}.

Any text that is not paired with an available filter key below will
be queried against all available data for each $filteredItem.

Available filters:
'''),
        Padding(
          padding: const EdgeInsets.only(left: defaultSpacing),
          child: Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final key in filterKeys)
                      Text(key, style: usageTextStyle),
                  ],
                ),
              ),
              const SizedBox(width: extraLargeSpacing),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final exampleUsage in filterExampleUsages)
                      Text('(e.g. $exampleUsage)', style: usageTextStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A class that stores information for a filter tag, which is a string
/// representation of a filter state.
///
/// This tag is used to identify filters in caches, like in user preferences
/// or in other screen specific data caches.
class FilterTag {
  FilterTag({
    required this.query,
    required this.settingFilterValues,
    required this.useRegExp,
  });

  static FilterTag? parse(String value) {
    final parts = value.split(filterTagSeparator);
    if (parts.length < 2) return null;
    try {
      final useRegExp = parts.last == useRegExpTag;
      final query = parts[0].trim();
      final settingFilterValues =
          (jsonDecode(parts[1]) as List).cast<Map<String, Object?>>();
      return FilterTag(
        query: query,
        settingFilterValues: settingFilterValues,
        useRegExp: useRegExp,
      );
    } catch (_) {
      // Return null for any parsing error.
      return null;
    }
  }

  static const filterTagSeparator = '|';
  static const useRegExpTag = 'regexp';

  final String query;
  final List<Map<String, Object?>> settingFilterValues;
  final bool useRegExp;

  String get tag => [
    query.trim(),
    jsonEncode(settingFilterValues),
    if (useRegExp) useRegExpTag,
  ].join(filterTagSeparator);
}
