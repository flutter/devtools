// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../dialogs.dart';
import '../theme.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

const int numOfMatchesToShow = 6;

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
  String _query;
  List<ScriptRef> _matches;

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

    _query = _autoCompleteController.search;
    _matches = widget.controller.sortedScripts.value;
  }

  void _handleSearch() {
    final query = _autoCompleteController.search;

    if (!query.startsWith(_query)) {
      setState(() {
        _matches = widget.controller.sortedScripts.value;
      });
    }

    final matches = findMatches(query, _matches);
    if (matches.isEmpty) {
      _autoCompleteController.searchAutoComplete.value = ['No files found.'];
    } else {
      final topMatches = takeTopMatches(matches);
      topMatches.forEach(_addScriptRefToCache);
      _autoCompleteController.searchAutoComplete.value =
          topMatches.map((scriptRef) => scriptRef.uri).toList();
    }

    setState(() {
      _query = query;
      _matches = matches;
    });
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: defaultBorderSide(theme),
        ),
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: buildAutoCompleteSearchField(
        controller: _autoCompleteController,
        searchFieldKey: fileSearchFieldKey,
        searchFieldEnabled: true,
        shouldRequestFocus: true,
        closeOverlayOnEscape: false,
        onSelection: _onSelection,
      ),
    );
  }

  void _onSelection(String scriptUri) {
    final scriptRef = _scriptsCache[scriptUri];
    widget.controller.showScriptLocation(ScriptLocation(scriptRef));
    _scriptsCache.clear();
    Navigator.of(context).pop(dialogDefaultContext);
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
  print('searching through ${scriptRefs.length} scripts');
  if (query.isEmpty) {
    return scriptRefs;
  }

  final exactMatches = scriptRefs
      .where((scriptRef) => scriptRef.uri.caseInsensitiveContains(query))
      .toList();

  if (exactMatches.length >= numOfMatchesToShow) {
    return exactMatches;
  }

  final fuzzyMatches = scriptRefs
      .where((scriptRef) => (
        print(scriptRef.uri.split('/'));
        return scriptRef.uri.caseInsensitiveFuzzyMatch(query);
        ),)
      .toList();

  return [...exactMatches, ...fuzzyMatches];
}

List<ScriptRef> takeTopMatches(List<ScriptRef> allMatches) {
  if (allMatches.length <= numOfMatchesToShow) {
    return allMatches;
  }

  return allMatches.sublist(0, numOfMatchesToShow);
}
