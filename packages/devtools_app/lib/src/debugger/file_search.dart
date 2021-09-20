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
    @required this.autoCompleteController,
  });

  final DebuggerController debuggerController;
  final AutoCompleteController autoCompleteController;

  @override
  _FileSearchFieldState createState() => _FileSearchFieldState();
}

class _FileSearchFieldState extends State<FileSearchField>
    with SearchFieldMixin, AutoDisposeMixin {
  final _scriptsCache = <String, ScriptRef>{};

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  String _query;
  List<ScriptRef> _matches;

  @override
  void initState() {
    super.initState();

    widget.autoCompleteController.currentDefaultIndex = 0;

    addAutoDisposeListener(
        widget.autoCompleteController.searchNotifier, _handleSearch);
    addAutoDisposeListener(
        widget.autoCompleteController.searchAutoCompleteNotifier,
        _handleAutoCompleteOverlay);

    _query = widget.autoCompleteController.search;
    _matches = widget.debuggerController.sortedScripts.value;

    // Open the autocomplete results immediately before a query is entered:
    SchedulerBinding.instance.addPostFrameCallback((_) => _handleSearch());
  }

  void _handleSearch() {
    final previousQuery = _query;
    final currentQuery = widget.autoCompleteController.search;

    // If the current query is a continuation of the previous query, then
    // whittle down the matches. Otherwise search through all scripts:
    final scripts = currentQuery.startsWith(previousQuery)
        ? _matches
        : widget.debuggerController.sortedScripts.value;

    final matches = findMatches(currentQuery, scripts);
    if (matches.isEmpty) {
      widget.autoCompleteController.searchAutoComplete.value = [
        AutoCompleteMatch('No files found.')
      ];
    } else {
      final topMatches = takeTopMatches(matches);
      topMatches.forEach(_addScriptRefToCache);
      widget.autoCompleteController.searchAutoComplete.value = topMatches
          .map((scriptRef) =>
              createAutoCompleteMatch(scriptRef.uri, currentQuery))
          .toList();
    }

    _query = currentQuery;
    _matches = matches;
  }

  void _handleAutoCompleteOverlay() {
    widget.autoCompleteController.handleAutoCompleteOverlay(
      context: context,
      searchFieldKey: fileSearchFieldKey,
      onTap: _onSelection,
      autocompleteMatchTileHeight: autocompleteMatchTileHeight,
    );
  }

  void _addScriptRefToCache(ScriptRef scriptRef) {
    _scriptsCache.putIfAbsent(scriptRef.uri, () => scriptRef);
  }

  @override
  Widget build(BuildContext context) {
    return buildAutoCompleteSearchField(
      controller: widget.autoCompleteController,
      searchFieldKey: fileSearchFieldKey,
      searchFieldEnabled: true,
      shouldRequestFocus: true,
      keyEventsToPropogate: {LogicalKeyboardKey.escape},
      onSelection: _onSelection,
      onClose: _onClose,
      label: 'Open',
    );
  }

  void _onSelection(String scriptUri) {
    final scriptRef = _scriptsCache[scriptUri];
    widget.debuggerController.showScriptLocation(ScriptLocation(scriptRef));
    _onClose();
  }

  void _onClose() {
    widget.autoCompleteController.closeAutoCompleteOverlay();
    widget.debuggerController.toggleFileOpenerVisibility(false);
    _scriptsCache.clear();
  }

  @override
  void dispose() {
    _onClose();
    widget.autoCompleteController.dispose();
    super.dispose();
  }
}

List<ScriptRef> findMatches(
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
    final fileName = scriptRef.uri.split('/').last;
    if (fullPath.caseInsensitiveContains(query)) {
      exactMatches.add(scriptRef);
    } else if (fileName.caseInsensitiveFuzzyMatch(query)) {
      fuzzyMatches.add(scriptRef);
    }
  }

  return [...exactMatches, ...fuzzyMatches];
}

List<ScriptRef> takeTopMatches(List<ScriptRef> allMatches) {
  if (allMatches.length <= numOfMatchesToShow) {
    return allMatches;
  }

  return allMatches.sublist(0, numOfMatchesToShow);
}

AutoCompleteMatch createAutoCompleteMatch(String match, String query) {
  final autoCompleteResultSegments = <AutoCompleteMatchSegment>[];

  if (match.contains(query)) {
    final start = match.indexOf(query);
    final end = start + query.length;
    autoCompleteResultSegments.add(AutoCompleteMatchSegment(start, end));
  } else {
    final fileName = match.split('/').last;
    var queryIndex = 0;
    for (int matchIndex = match.indexOf(fileName);
        matchIndex < match.length;
        matchIndex++) {
      if (queryIndex == query.length) break;
      if (match[matchIndex] == query[queryIndex]) {
        final start = matchIndex;
        final end = matchIndex + 1;
        autoCompleteResultSegments.add(AutoCompleteMatchSegment(start, end));
        queryIndex++;
      }
    }
  }

  return AutoCompleteMatch(match,
      highlightedSegments: autoCompleteResultSegments);
}
