// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import '../../ui/search.dart';
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

    autoCompleteController = AutoCompleteController();
    autoCompleteController.setCurrentHoveredIndexValue(0);

    addAutoDisposeListener(
        autoCompleteController.searchNotifier, _handleSearch);
    addAutoDisposeListener(autoCompleteController.searchAutoCompleteNotifier,
        _handleAutoCompleteOverlay);

    _query = autoCompleteController.search;

    _searchResults = FileSearchResults.emptyQuery(
      scriptManager.sortedScripts.value,
    );

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
      label: 'Open file',
      onFocusLost: _onClose,
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
    final currentQuery = autoCompleteController.search.trim();

    // If the current query is a continuation of the previous query, then
    // filter down the previous matches. Otherwise search through all scripts:
    final scripts = currentQuery.startsWith(previousQuery)
        ? _searchResults.scriptRefs
        : scriptManager.sortedScripts.value;

    final searchResults = _createSearchResults(currentQuery, scripts);
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

  FileSearchResults _createSearchResults(
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

  final String query;

  bool get isEmpty => query.isEmpty;

  bool get isMultiToken => query.contains(' ');

  List<String> get tokens => query.split(' ');

  bool isExactFileNameMatch(ScriptRef script) {
    if (isEmpty) return false;

    final fileName = _fileName(script.uri);

    if (isMultiToken) {
      return tokens.every((token) => fileName.caseInsensitiveContains(token));
    }

    return fileName.caseInsensitiveContains(query);
  }

  AutoCompleteMatch createExactFileNameAutoCompleteMatch(ScriptRef script) {
    if (isEmpty) return AutoCompleteMatch(script.uri);

    final fileName = _fileName(script.uri);
    final fileNameIndex = script.uri.lastIndexOf(fileName);
    final matchedSegments = _findExactSegments(fileName)
        .map((range) =>
            Range(range.begin + fileNameIndex, range.end + fileNameIndex))
        .toList();
    return AutoCompleteMatch(script.uri, matchedSegments: matchedSegments);
  }

  bool isExactFullPathMatch(ScriptRef script) {
    if (isEmpty) return false;

    if (isMultiToken) {
      return tokens.every((token) => script.uri.caseInsensitiveContains(token));
    }

    return script.uri.caseInsensitiveContains(query);
  }

  AutoCompleteMatch createExactFullPathAutoCompleteMatch(ScriptRef script) {
    if (isEmpty) return AutoCompleteMatch(script.uri);

    final matchedSegments = _findExactSegments(script.uri);
    return AutoCompleteMatch(script.uri, matchedSegments: matchedSegments);
  }

  bool isFuzzyMatch(ScriptRef script) {
    if (isEmpty) return false;

    if (isMultiToken) {
      return script.uri.caseInsensitiveFuzzyMatch(query.replaceAll(' ', ''));
    }

    return _fileName(script.uri).caseInsensitiveFuzzyMatch(query);
  }

  AutoCompleteMatch createFuzzyMatchAutoCompleteMatch(ScriptRef script) {
    if (isEmpty) return AutoCompleteMatch(script.uri);

    List<Range> matchedSegments;
    if (isMultiToken) {
      matchedSegments =
          _findFuzzySegments(script.uri, query.replaceAll(' ', ''));
    } else {
      final fileName = _fileName(script.uri);
      final fileNameIndex = script.uri.lastIndexOf(fileName);
      matchedSegments = _findFuzzySegments(fileName, query)
          .map((range) =>
              Range(range.begin + fileNameIndex, range.end + fileNameIndex))
          .toList();
    }

    return AutoCompleteMatch(script.uri, matchedSegments: matchedSegments);
  }

  List<Range> _findExactSegments(String file) {
    final matchedSegments = <Range>[];
    for (final token in isMultiToken ? tokens : [query]) {
      final start = file.indexOf(token);
      final end = start + token.length;
      matchedSegments.add(Range(start, end));
    }
    matchedSegments
        .sort((rangeA, rangeB) => rangeA.begin.compareTo(rangeB.begin));

    return matchedSegments;
  }

  List<Range> _findFuzzySegments(String file, String query) {
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

  String _fileName(String fullPath) {
    return _fileNamesCache[fullPath] ??= fullPath.split('/').last;
  }
}

class FileSearchResults {
  factory FileSearchResults.emptyQuery(List<ScriptRef> allScripts) {
    return FileSearchResults._(
      query: FileQuery.empty(),
      allScripts: allScripts,
      exactFileNameMatches: [],
      exactFullPathMatches: [],
      fuzzyMatches: [],
    );
  }

  factory FileSearchResults.withQuery({
    @required FileQuery query,
    @required List<ScriptRef> allScripts,
  }) {
    assert(!query.isEmpty);
    final List<ScriptRef> exactFileNameMatches = [];
    final List<ScriptRef> exactFullPathMatches = [];
    final List<ScriptRef> fuzzyMatches = [];

    for (final scriptRef in allScripts) {
      if (query.isExactFileNameMatch(scriptRef)) {
        exactFileNameMatches.add(scriptRef);
      } else if (query.isExactFullPathMatch(scriptRef)) {
        exactFullPathMatches.add(scriptRef);
      } else if (query.isFuzzyMatch(scriptRef)) {
        fuzzyMatches.add(scriptRef);
      }
    }

    return FileSearchResults._(
      query: query,
      allScripts: allScripts,
      exactFileNameMatches: exactFileNameMatches,
      exactFullPathMatches: exactFullPathMatches,
      fuzzyMatches: fuzzyMatches,
    );
  }

  FileSearchResults._({
    @required this.query,
    @required this.allScripts,
    @required List<ScriptRef> exactFileNameMatches,
    @required List<ScriptRef> exactFullPathMatches,
    @required List<ScriptRef> fuzzyMatches,
  })  : _exactFileNameMatches = exactFileNameMatches,
        _exactFullPathMatches = exactFullPathMatches,
        _fuzzyMatches = fuzzyMatches;

  final List<ScriptRef> allScripts;
  final FileQuery query;
  final List<ScriptRef> _exactFileNameMatches;
  final List<ScriptRef> _exactFullPathMatches;
  final List<ScriptRef> _fuzzyMatches;

  FileSearchResults get topMatches => _buildTopMatches();

  List<ScriptRef> get scriptRefs => query.isEmpty
      ? allScripts
      : [
          ..._exactFileNameMatches,
          ..._exactFullPathMatches,
          ..._fuzzyMatches,
        ];

  List<AutoCompleteMatch> get autoCompleteMatches => query.isEmpty
      ? allScripts.map((script) => AutoCompleteMatch(script.uri)).toList()
      : [
          ..._exactFileNameMatches
              .map(query.createExactFileNameAutoCompleteMatch)
              .toList(),
          ..._exactFullPathMatches
              .map(query.createExactFullPathAutoCompleteMatch)
              .toList(),
          ..._fuzzyMatches
              .map(query.createFuzzyMatchAutoCompleteMatch)
              .toList(),
        ];

  FileSearchResults copyWith({
    List<ScriptRef> allScripts,
    FileQuery query,
    List<ScriptRef> exactFileNameMatches,
    List<ScriptRef> exactFullPathMatches,
    List<ScriptRef> fuzzyMatches,
  }) {
    return FileSearchResults._(
      query: query ?? this.query,
      allScripts: allScripts ?? this.allScripts,
      exactFileNameMatches: exactFileNameMatches ?? _exactFileNameMatches,
      exactFullPathMatches: exactFullPathMatches ?? _exactFullPathMatches,
      fuzzyMatches: fuzzyMatches ?? _fuzzyMatches,
    );
  }

  FileSearchResults _buildTopMatches() {
    if (query.isEmpty) {
      return copyWith(
        allScripts: allScripts.sublist(0, numOfMatchesToShow),
      );
    }

    if (scriptRefs.length <= numOfMatchesToShow) {
      return copyWith();
    }

    final topMatches = [];
    int matchesLeft = numOfMatchesToShow;
    for (final matches in [
      _exactFileNameMatches,
      _exactFullPathMatches,
      _fuzzyMatches
    ]) {
      final selected = _takeMatches(matches, matchesLeft);
      topMatches.add(selected);
      matchesLeft -= selected.length;
    }

    return copyWith(
      exactFileNameMatches: topMatches[0],
      exactFullPathMatches: topMatches[1],
      fuzzyMatches: topMatches[2],
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
