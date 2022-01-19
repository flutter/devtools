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

final _fileNamesCache = <String, String>{};

class FileSearchField extends StatefulWidget {
  const FileSearchField({
    @required this.debuggerController,
  });

  final DebuggerController debuggerController;

  @override
  FileSearchFieldState createState() => FileSearchFieldState();
}

class FileSearchFieldState extends State<FileSearchField>
    with AutoDisposeMixin, SearchFieldMixin {
  AutoCompleteController autoCompleteController;

  final _scriptsCache = <String, ScriptRef>{};

  final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  String _query;
  FileSearchResults _searchResults;

  @override
  void initState() {
    super.initState();

    autoCompleteController = AutoCompleteController()..currentDefaultIndex = 0;

    addAutoDisposeListener(
        autoCompleteController.searchNotifier, _handleSearch);
    addAutoDisposeListener(autoCompleteController.searchAutoCompleteNotifier,
        _handleAutoCompleteOverlay);

    _query = autoCompleteController.search;
    _searchResults = FileSearchResults.emptyQuery(
        widget.debuggerController.sortedScripts.value);

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
      keyEventsToPropagate: {LogicalKeyboardKey.escape},
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
        ? _searchResults.scriptRefs
        : widget.debuggerController.sortedScripts.value;

    final searchResults = _getSearchResults(currentQuery, scripts);
    if (searchResults.scriptRefs.isEmpty) {
      autoCompleteController.searchAutoComplete.value = [];
    } else {
      searchResults.topMatches.scriptRefs.forEach(_addScriptRefToCache);
      autoCompleteController.searchAutoComplete.value =
          searchResults.topMatches.autoCompleteMatches;
    }

    _query = currentQuery;
    _searchResults = searchResults;
  }

  void _handleAutoCompleteOverlay() {
    autoCompleteController.handleAutoCompleteOverlay(
      context: context,
      searchFieldKey: fileSearchFieldKey,
      onTap: _onSelection,
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
    _fileNamesCache.clear();
    _scriptsCache.clear();
  }

  FileSearchResults _getSearchResults(
    String query,
    List<ScriptRef> scriptRefs,
  ) {
    if (query.isEmpty) {
      return FileSearchResults.emptyQuery(scriptRefs);
    }

    return FileSearchResults.withQuery(
      allScripts: scriptRefs,
      query: FileQuery(query),
    );
  }
}

class FileQuery {
  FileQuery(this.query) : assert(query.isNotEmpty);

  FileQuery.empty() : query = '';

  String query;

  bool get isEmpty => query.isEmpty;

  bool isExactFullPathMatch(ScriptRef script) {
    if (isEmpty) return false;
    return script.uri.caseInsensitiveContains(query);
  }

  AutoCompleteMatch createExactFullPathAutoCompleteMatch(ScriptRef script) {
    if (isEmpty) return AutoCompleteMatch(script.uri);

    final matchedSegments = _findExactSegments(script.uri);
    return AutoCompleteMatch(script.uri, matchedSegments: matchedSegments);
  }

  bool isFuzzyMatch(ScriptRef script) {
    if (isEmpty) return false;

    final fileName = _getFileName(script.uri);
    return fileName.caseInsensitiveFuzzyMatch(query);
  }

  AutoCompleteMatch createFuzzyMatchAutoCompleteMatch(ScriptRef script) {
    if (isEmpty) return AutoCompleteMatch(script.uri);

    final fileName = _getFileName(script.uri);
    final fileNameIdx = script.uri.lastIndexOf(fileName);
    final matchedSegments = _findFuzzySegments(fileName)
        .map((range) =>
            Range(range.begin + fileNameIdx, range.end + fileNameIdx))
        .toList();

    return AutoCompleteMatch(script.uri, matchedSegments: matchedSegments);
  }

  List<Range> _findExactSegments(String file) {
    final autoCompleteResultSegments = <Range>[];
    final start = file.indexOf(query);
    final end = start + query.length;
    autoCompleteResultSegments.add(Range(start, end));
    return autoCompleteResultSegments;
  }

  List<Range> _findFuzzySegments(String file) {
    final autoCompleteResultSegments = <Range>[];
    var queryIndex = 0;
    for (int matchIndex = 0; matchIndex < file.length; matchIndex++) {
      if (queryIndex == query.length) break;
      if (file[matchIndex] == query[queryIndex]) {
        final start = matchIndex;
        final end = matchIndex + 1;
        autoCompleteResultSegments.add(Range(start, end));
        queryIndex++;
      }
    }
    return autoCompleteResultSegments;
  }

  String _getFileName(String fullPath) {
    return _fileNamesCache[fullPath] ??= fullPath.split('/').last;
  }
}

class FileSearchResults {
  FileSearchResults.emptyQuery(this.allScripts) : query = FileQuery.empty();

  FileSearchResults.withQuery({
    @required this.query,
    @required this.allScripts,
  }) {
    // ignore: prefer_asserts_in_initializer_lists
    assert(!query.isEmpty);

    for (final scriptRef in allScripts) {
      if (query.isExactFullPathMatch(scriptRef)) {
        _exactFullPathMatches.add(scriptRef);
      } else if (query.isFuzzyMatch(scriptRef)) {
        _fuzzyMatches.add(scriptRef);
      }
    }
  }

  FileSearchResults._({
    @required this.query,
    @required this.allScripts,
    @required exactFullPathMatches,
    @required fuzzyMatches,
  }) {
    _exactFullPathMatches.addAll(exactFullPathMatches);
    _fuzzyMatches.addAll(fuzzyMatches);
  }

  final List<ScriptRef> allScripts;
  final FileQuery query;
  final List<ScriptRef> _exactFullPathMatches = [];
  final List<ScriptRef> _fuzzyMatches = [];

  FileSearchResults get topMatches => _buildTopMatches();

  List<ScriptRef> get scriptRefs =>
      query.isEmpty ? allScripts : [..._exactFullPathMatches, ..._fuzzyMatches];

  List<AutoCompleteMatch> get autoCompleteMatches => query.isEmpty
      ? allScripts.map((script) => AutoCompleteMatch(script.uri)).toList()
      : [
          ..._exactFullPathMatches
              .map(query.createExactFullPathAutoCompleteMatch)
              .toList(),
          ..._fuzzyMatches
              .map(query.createFuzzyMatchAutoCompleteMatch)
              .toList(),
        ];

  FileSearchResults _buildTopMatches() {
    if (query.isEmpty) {
      return FileSearchResults.emptyQuery(
        allScripts.sublist(
          0,
          numOfMatchesToShow,
        ),
      );
    }

    if (scriptRefs.length <= numOfMatchesToShow) {
      // Make a copy of this:
      return FileSearchResults._(
        allScripts: allScripts,
        query: query,
        exactFullPathMatches: _exactFullPathMatches,
        fuzzyMatches: _fuzzyMatches,
      );
    }

    final topMatches = [];
    int matchesLeft = numOfMatchesToShow;
    for (final matches in [_exactFullPathMatches, _fuzzyMatches]) {
      final selected = _takeMatches(matches, matchesLeft);
      topMatches.add(selected);
      matchesLeft -= selected.length;
    }

    return FileSearchResults._(
      allScripts: allScripts,
      query: query,
      exactFullPathMatches: topMatches[0],
      fuzzyMatches: topMatches[1],
    );
  }

  List<ScriptRef> _takeMatches(List<ScriptRef> matches, int numToTake) {
    if (numToTake <= 0) {
      return [];
    }
    if (matches.length > numToTake) {
      return matches.sublist(0, numToTake);
    }
    return matches;
  }
}
