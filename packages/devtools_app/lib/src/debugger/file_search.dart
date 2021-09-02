// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
import '../ui/search.dart';
import 'debugger_controller.dart';

class FileSearchField extends StatefulWidget {
  const FileSearchField({
    @required this.controller,
  });

  final DebuggerController controller;

  @override
  _FileSearchFieldState createState() => _FileSearchFieldState();
}

class _FileSearchFieldState extends State<FileSearchField>
    with SearchFieldMixin, AutoDisposeMixin {
  AutoCompleteController _autoCompleteController;
  int historyPosition = -1;

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  @override
  void initState() {
    super.initState();

    _autoCompleteController = AutoCompleteController();
    _autoCompleteController.currentDefaultIndex = 0;

    addAutoDisposeListener(_autoCompleteController.searchNotifier, () {
      _autoCompleteController.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: fileSearchFieldKey,
        onTap: _onSelection,
      );
    });
    addAutoDisposeListener(
        _autoCompleteController.selectTheSearchNotifier, _handleSearch);
    addAutoDisposeListener(
        _autoCompleteController.searchNotifier, _handleSearch);
  }

  void _handleSearch() async {
    final searchingValue = _autoCompleteController.search;
    print('searching value is $searchingValue');
    final matches = await autoCompleteResultsFor(widget.controller);
    _autoCompleteController.searchAutoComplete.value = matches;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.focusColor),
        ),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const SizedBox(width: 8.0),
          Expanded(
            child: buildAutoCompleteSearchField(
              controller: _autoCompleteController,
              searchFieldKey: fileSearchFieldKey,
              searchFieldEnabled: true,
              shouldRequestFocus: true,
              onSelection: _onSelection,
            ),
          ),
        ],
      ),
    );
  }

  void _onSelection(String file) {
    print('SELECTED $file');
  }

  @override
  void dispose() {
    _autoCompleteController.dispose();
    super.dispose();
  }
}

Future<List<String>> autoCompleteResultsFor(
  DebuggerController controller,
) async {
  final results = ['elephant', 'cat', 'dog', 'anteater', 'bird', 'squirrel'];
  results.shuffle();
  return Future<List<String>>.value(results);
}
