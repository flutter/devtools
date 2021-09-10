// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

const int numOfMatchesToShow = 10;

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

  final _scriptsCache = <String, ScriptRef>{};

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  @override
  void initState() {
    super.initState();

    _autoCompleteController = AutoCompleteController()..currentDefaultIndex = 0;

    addAutoDisposeListener(
        _autoCompleteController.searchNotifier, _handleSearch);
    addAutoDisposeListener(_autoCompleteController.searchAutoCompleteNotifier,
        _handleAutoCompleteOverlay);

    // Open the autocomplete results immediately before a query is entered:
    SchedulerBinding.instance.addPostFrameCallback((_) => _handleSearch());
  }

  void _handleSearch() {
    final query = _autoCompleteController.search;
    final matches = findMatches(query, widget.controller.sortedScripts.value);
    if (matches.isEmpty) {
      _autoCompleteController.searchAutoComplete.value = ['No files found.'];
    } else {
      matches.forEach(_addScriptRefToCache);
      _autoCompleteController.searchAutoComplete.value =
          matches.map((scriptRef) => scriptRef.uri).toList();
    }
  }

  void _handleAutoCompleteOverlay() {
    _autoCompleteController.handleAutoCompleteOverlay(
      context: context,
      searchFieldKey: fileSearchFieldKey,
      onTap: _onSelection,
    );
  }

  void _addScriptRefToCache(ScriptRef scriptRef) {
    _scriptsCache.putIfAbsent(scriptRef.uri, () => scriptRef);
  }

  @override
  Widget build(BuildContext context) {
    return buildAutoCompleteSearchField(
      controller: _autoCompleteController,
      searchFieldKey: fileSearchFieldKey,
      searchFieldEnabled: true,
      shouldRequestFocus: true,
      keyEventsToPropogate: {LogicalKeyboardKey.escape},
      onSelection: _onSelection,
      onClose: _onClose,
    );
  }

  void _onSelection(String scriptUri) {
    final scriptRef = _scriptsCache[scriptUri];
    widget.controller.showScriptLocation(ScriptLocation(scriptRef));
    _onClose();
  }

  void _onClose() {
    setState(() {
      _autoCompleteController.closeAutoCompleteOverlay();
    });
    widget.controller.toggleFileOpener(false);
    _scriptsCache.clear();
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

  return takeTopMatches([...exactMatches, ...fuzzyMatches]);
}

List<ScriptRef> takeTopMatches(List<ScriptRef> allMatches) {
  if (allMatches.length <= numOfMatchesToShow) {
    return allMatches;
  }

  return allMatches.sublist(0, numOfMatchesToShow);
}
