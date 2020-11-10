import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'label.dart';

mixin FilterControllerMixin<T> {
  final filteredData = ValueNotifier<List<T>>([]);

  final activeFilter = ValueNotifier<QueryFilter>(null);

  Map<String, FilterArgument> get filterArgs;

  void filterData(QueryFilter filter);

  void resetFilter() {
    activeFilter.value = null;
  }
}

class FilterDialog<FilterControllerMixin> extends StatefulWidget {
  const FilterDialog({
    @required this.controller,
    @required this.onApplyFilter,
    @required this.queryInstructions,
  });

  final FilterControllerMixin controller;

  final void Function(String query) onApplyFilter;

  final String queryInstructions;

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  static const dialogWidth = 500.0;

  TextEditingController queryTextFieldController;

  @override
  void initState() {
    super.initState();
    queryTextFieldController = TextEditingController(
        text: widget.controller.activeFilter.value?.query ?? '');
  }

  @override
  void dispose() {
    queryTextFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: _buildDialogTitle(),
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
        ),
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQueryTextField(),
            const SizedBox(height: defaultSpacing),
            _buildQueryInstructions(),
          ],
        ),
      ),
      actions: [
        DialogApplyButton(
          onPressed: () =>
              widget.onApplyFilter(queryTextFieldController.value.text),
        ),
        DialogCancelButton(),
      ],
    );
  }

  Widget _buildDialogTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        dialogTitleText(Theme.of(context), 'Filters'),
        FlatButton(
          onPressed: queryTextFieldController.clear,
          child: const MaterialIconLabel(
            Icons.replay,
            'Reset to default',
          ),
        ),
      ],
    );
  }

  Widget _buildQueryTextField() {
    return Container(
      height: defaultTextFieldHeight,
      child: TextField(
        controller: queryTextFieldController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(denseSpacing),
          border: const OutlineInputBorder(),
          labelText: 'Filter query',
          suffix: clearInputButton(queryTextFieldController.clear),
        ),
      ),
    );
  }

  Widget _buildQueryInstructions() {
    return Text(
      widget.queryInstructions,
      style: Theme.of(context).subtleTextStyle,
    );
  }
}

class QueryFilter<T> {
  QueryFilter({
    this.filterArguments,
    this.substrings = const [],
  });

  factory QueryFilter.parse(String query, Map<String, FilterArgument> args) {
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
              arg.isNegative = part.startsWith(FilterArgument.negativePrefix);
              arg.values = value.split(FilterArgument.valueSeparator);
            }
          }
        }
      } else {
        substrings.add(part);
      }
    }
    return QueryFilter(filterArguments: args, substrings: substrings);
  }

  final Map<String, FilterArgument> filterArguments;

  final List<String> substrings;

  String get query => [
        ...substrings,
        for (final arg in filterArguments.values) arg.display,
      ].join(' ').trim();
}

class FilterArgument {
  FilterArgument({
    @required this.keys,
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

  bool matchesValue(String dataValue) {
    // If there are no specified filter values, consider [dataValue] to match
    // this filter.
    if (values.isEmpty) return true;

    var matches = false;
    for (final value in values) {
      matches = dataValue == value.toLowerCase();
      if (matches) break;
    }
    return isNegative ? !matches : matches;
  }

  void reset() {
    values = [];
    isNegative = false;
  }
}
