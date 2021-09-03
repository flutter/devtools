// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

const int numOfMatchesToShow = 5;

class FileSearchField extends StatefulWidget {
  const FileSearchField({
    @required this.controller,
    @required this.handleClose,
  });

  final DebuggerController controller;
  final Function handleClose;

  @override
  _FileSearchFieldState createState() => _FileSearchFieldState();
}

class _FileSearchFieldState extends State<FileSearchField>
    with SearchFieldMixin, AutoDisposeMixin {
  AutoCompleteController _autoCompleteController;
  final Map<String, ScriptRef> _scriptsCache = {};

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  @override
  void initState() {
    super.initState();

    _autoCompleteController = AutoCompleteController();
    _autoCompleteController.currentDefaultIndex = 0;

    addAutoDisposeListener(
        _autoCompleteController.selectTheSearchNotifier, _handleSearch);
    addAutoDisposeListener(
        _autoCompleteController.searchNotifier, _handleSearch);

    _autoCompleteController.selectTheSearch = true;
  }

  void _handleSearch() {
    final query = _autoCompleteController.search;
    final matches = findMatches(query, widget.controller.sortedScripts.value);
    matches.forEach(_addScriptRefToCache);
    _autoCompleteController.searchAutoComplete.value =
        matches.map((scriptRef) => scriptRef.uri).toList();
    _handleAutoCompleteOverlay();
  }

  void _handleAutoCompleteOverlay() {
    _autoCompleteController.handleAutoCompleteOverlay(
      context: context,
      searchFieldKey: fileSearchFieldKey,
      onTap: _onSelection,
    );
  }

  void _addScriptRefToCache(ScriptRef scriptRef) {
    if (!_scriptsCache.containsKey(scriptRef.uri)) {
      _scriptsCache[scriptRef.uri] = scriptRef;
    }
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

  void _onSelection(String scriptUri) {
    final scriptRef = _scriptsCache[scriptUri];
    widget.controller.showScriptLocation(ScriptLocation(scriptRef));
    _scriptsCache.clear();
    widget.handleClose();
  }

  @override
  void dispose() {
    _autoCompleteController.dispose();
    super.dispose();
  }
}

List<ScriptRef> findMatches(
  String query,
  List<ScriptRef> scriptRefs,
) {
  if (query.isEmpty) {
    takeTopMatches(scriptRefs);
  }

  final exactMatches = scriptRefs
      .where((scriptRef) => scriptRef.uri.caseInsensitiveContains(query))
      .toList();

  if (exactMatches.length >= numOfMatchesToShow) {
    return takeTopMatches(exactMatches);
  }

  final fuzzyMatches = scriptRefs
      .where((scriptRef) => scriptRef.uri.caseInsensitiveFuzzyMatch(query))
      .toList();

  return takeTopMatches([...exactMatches, ...fuzzyMatches, ...scriptRefs]);
}

List<ScriptRef> takeTopMatches(List<ScriptRef> allMatches) {
  if (allMatches.length <= numOfMatchesToShow) {
    return allMatches;
  }

  return allMatches.sublist(0, numOfMatchesToShow);
}
