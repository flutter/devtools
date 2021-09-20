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
const double autocompleteMatchTileHeight = 50.0;

class FileSearchField extends StatefulWidget {
  const FileSearchField({
    @required this.debuggerController,
  });

  final DebuggerController debuggerController;

  @override
  FileSearchFieldState createState() => FileSearchFieldState();
}

class FileSearchFieldState extends State<FileSearchField>
    with SearchFieldMixin, AutoDisposeMixin {
  AutoCompleteController autoCompleteController;

  final _scriptsCache = <String, ScriptRef>{};
  final _fileNamesCache = <String, String>{};

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  String _query;
  List<ScriptRef> _matches;

  @override
  void initState() {
    super.initState();

    autoCompleteController = AutoCompleteController()..currentDefaultIndex = 0;

    addAutoDisposeListener(
        autoCompleteController.searchNotifier, _handleSearch);
    addAutoDisposeListener(autoCompleteController.searchAutoCompleteNotifier,
        _handleAutoCompleteOverlay);

    _query = autoCompleteController.search;
    _matches = widget.debuggerController.sortedScripts.value;

    // Open the autocomplete results immediately before a query is entered:
    SchedulerBinding.instance.addPostFrameCallback((_) => _handleSearch());
  }

  @override
  Widget build(BuildContext context) {
    return buildAutoCompleteSearchField(
      controller: autoCompleteController,
      searchFieldKey: fileSearchFieldKey,
      searchFieldEnabled: true,
      shouldRequestFocus: true,
      keyEventsToPropogate: {LogicalKeyboardKey.escape},
      onSelection: _onSelection,
      onClose: _onClose,
      label: 'Open',
    );
  }

  @override
  void dispose() {
    _onClose();
    autoCompleteController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final previousQuery = _query;
    final currentQuery = autoCompleteController.search;

    // If the current query is a continuation of the previous query, then
    // filter down the previous matches. Otherwise search through all scripts:
    final scripts = currentQuery.startsWith(previousQuery)
        ? _matches
        : widget.debuggerController.sortedScripts.value;

    final matches = _findMatches(currentQuery, scripts);
    if (matches.isEmpty) {
      autoCompleteController.searchAutoComplete.value = ['No files found.'];
    } else {
      final topMatches = _takeTopMatches(matches);
      topMatches.forEach(_addScriptRefToCache);
      autoCompleteController.searchAutoComplete.value =
          topMatches.map((scriptRef) => scriptRef.uri).toList();
    }

    _query = currentQuery;
    _matches = matches;
  }

  void _handleAutoCompleteOverlay() {
    autoCompleteController.handleAutoCompleteOverlay(
      context: context,
      searchFieldKey: fileSearchFieldKey,
      onTap: _onSelection,
      autocompleteMatchTileHeight: autocompleteMatchTileHeight,
    );
  }

  void _addScriptRefToCache(ScriptRef scriptRef) {
    _scriptsCache.putIfAbsent(scriptRef.uri, () => scriptRef);
  }

  void _onSelection(String scriptUri) {
    final scriptRef = _scriptsCache[scriptUri];
    widget.debuggerController.showScriptLocation(ScriptLocation(scriptRef));
    _onClose();
  }

  void _onClose() {
    autoCompleteController.closeAutoCompleteOverlay();
    widget.debuggerController.toggleFileOpenerVisibility(false);
    _scriptsCache.clear();
  }

  List<ScriptRef> _findMatches(
    String query,
    List<ScriptRef> scriptRefs,
  ) {
    if (query.isEmpty) {
      return scriptRefs;
    }

    final exactMatches = [];
    final fuzzyMatches = [];

    for (final scriptRef in scriptRefs) {
      final fullPath = scriptRef.uri;
      final fileName =
          _fileNamesCache[scriptRef.uri] ??= scriptRef.uri.split('/').last;
      if (fullPath.caseInsensitiveContains(query)) {
        exactMatches.add(scriptRef);
      } else if (fileName.caseInsensitiveFuzzyMatch(query)) {
        fuzzyMatches.add(scriptRef);
      }
    }

    return [...exactMatches, ...fuzzyMatches];
  }

  List<ScriptRef> _takeTopMatches(List<ScriptRef> allMatches) {
    if (allMatches.length <= numOfMatchesToShow) {
      return allMatches;
    }

    return allMatches.sublist(0, numOfMatchesToShow);
  }
}
