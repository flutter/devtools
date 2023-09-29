// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/search.dart';
import 'codeview_controller.dart';
import 'debugger_model.dart';

const int numOfMatchesToShow = 10;

const noResultsMsg = 'No files found.';

final _fileNamesCache = <String, String>{};

class FileSearchField extends StatefulWidget {
  const FileSearchField({
    super.key,
    required this.codeViewController,
  });

  final CodeViewController codeViewController;

  @override
  FileSearchFieldState createState() => FileSearchFieldState();
}

class FileSearchFieldState extends State<FileSearchField>
    with AutoDisposeMixin, SearchFieldMixin {
  static final fileSearchFieldKey = GlobalKey(debugLabel: 'fileSearchFieldKey');

  final autoCompleteController = AutoCompleteController(fileSearchFieldKey);

  final _scriptsCache = <String, ScriptRef>{};

  late String _query;
  late FileSearchResults _searchResults;

  @override
  SearchControllerMixin get searchController => autoCompleteController;

  @override
  void initState() {
    super.initState();

    autoCompleteController.setCurrentHoveredIndexValue(0);

    addAutoDisposeListener(
      autoCompleteController.searchNotifier,
      _handleSearch,
    );
    addAutoDisposeListener(
      autoCompleteController.searchAutoCompleteNotifier,
      _handleAutoCompleteOverlay,
    );

    _query = autoCompleteController.search;

    _searchResults = FileSearchResults.emptyQuery(
      scriptManager.sortedScripts.value,
    );

    // Open the autocomplete results immediately before a query is entered:
    SchedulerBinding.instance.addPostFrameCallback((_) => _handleSearch());
  }

  @override
  Widget build(BuildContext context) {
    return AutoCompleteSearchField(
      controller: autoCompleteController,
      searchFieldEnabled: true,
      shouldRequestFocus: true,
      keyEventsToIgnore: {LogicalKeyboardKey.escape},
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
      autoCompleteController.searchAutoComplete.value = [
        AutoCompleteMatch(noResultsMsg),
      ];
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
    final uri = scriptRef.uri;
    if (uri == null) return;
    _scriptsCache.putIfAbsent(uri, () => scriptRef);
  }

  Future<void> _onSelection(String scriptUri) async {
    if (scriptUri == noResultsMsg) {
      _onClose();
      return;
    }
    final scriptRef = _scriptsCache[scriptUri]!;
    await widget.codeViewController
        .showScriptLocation(ScriptLocation(scriptRef));
    _onClose();
  }

  void _onClose() {
    autoCompleteController.closeAutoCompleteOverlay();
    widget.codeViewController.toggleFileOpenerVisibility(false);
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

    final scriptUri = script.uri!;
    final fileName = _fileName(scriptUri);

    if (isMultiToken) {
      return tokens.every((token) => fileName.caseInsensitiveContains(token));
    }

    return fileName.caseInsensitiveContains(query);
  }

  AutoCompleteMatch createExactFileNameAutoCompleteMatch(ScriptRef script) {
    final scriptUri = script.uri!;
    if (isEmpty) return AutoCompleteMatch(scriptUri);

    final fileName = _fileName(scriptUri);
    final fileNameIndex = scriptUri.lastIndexOf(fileName);
    final matchedSegments = _findExactSegments(fileName)
        .map(
          (range) =>
              Range(range.begin + fileNameIndex, range.end + fileNameIndex),
        )
        .toList();
    return AutoCompleteMatch(scriptUri, matchedSegments: matchedSegments);
  }

  bool isExactFullPathMatch(ScriptRef script) {
    if (isEmpty) return false;

    final scriptUri = script.uri!;
    if (isMultiToken) {
      return tokens.every((token) => scriptUri.caseInsensitiveContains(token));
    }

    return scriptUri.caseInsensitiveContains(query);
  }

  AutoCompleteMatch createExactFullPathAutoCompleteMatch(ScriptRef script) {
    final scriptUri = script.uri!;
    if (isEmpty) return AutoCompleteMatch(scriptUri);

    final matchedSegments = _findExactSegments(scriptUri);
    return AutoCompleteMatch(scriptUri, matchedSegments: matchedSegments);
  }

  bool isFuzzyMatch(ScriptRef script) {
    if (isEmpty) return false;
    final scriptUri = script.uri!;

    if (isMultiToken) {
      return scriptUri.caseInsensitiveFuzzyMatch(query.replaceAll(' ', ''));
    }

    return _fileName(scriptUri).caseInsensitiveFuzzyMatch(query);
  }

  AutoCompleteMatch createFuzzyMatchAutoCompleteMatch(ScriptRef script) {
    final scriptUri = script.uri!;
    if (isEmpty) return AutoCompleteMatch(scriptUri);

    List<Range> matchedSegments;
    if (isMultiToken) {
      matchedSegments =
          _findFuzzySegments(scriptUri, query.replaceAll(' ', ''));
    } else {
      final fileName = _fileName(scriptUri);
      final fileNameIndex = scriptUri.lastIndexOf(fileName);
      matchedSegments = _findFuzzySegments(fileName, query)
          .map(
            (range) =>
                Range(range.begin + fileNameIndex, range.end + fileNameIndex),
          )
          .toList();
    }

    return AutoCompleteMatch(scriptUri, matchedSegments: matchedSegments);
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
    required FileQuery query,
    required List<ScriptRef> allScripts,
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
    required this.query,
    required this.allScripts,
    required List<ScriptRef> exactFileNameMatches,
    required List<ScriptRef> exactFullPathMatches,
    required List<ScriptRef> fuzzyMatches,
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
      ? allScripts.map((script) => AutoCompleteMatch(script.uri!)).toList()
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
    List<ScriptRef>? allScripts,
    FileQuery? query,
    List<ScriptRef>? exactFileNameMatches,
    List<ScriptRef>? exactFullPathMatches,
    List<ScriptRef>? fuzzyMatches,
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
      _fuzzyMatches,
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
