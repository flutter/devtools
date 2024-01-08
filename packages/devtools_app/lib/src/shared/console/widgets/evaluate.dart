// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as gac;
import '../../globals.dart';
import '../../ui/search.dart';
import '../../ui/utils.dart';
import '../../utils.dart';
import '../eval/auto_complete.dart';
import '../eval/eval_service.dart';
import '../primitives/assignment.dart';
import '../primitives/eval_history.dart';
import 'help_dialog.dart';

typedef AutoCompleteResultsFunction = Future<List<String>> Function(
  EditingParts parts,
  EvalService evalService,
);

class ExpressionEvalField extends StatefulWidget {
  const ExpressionEvalField({
    super.key,
    AutoCompleteResultsFunction? getAutoCompleteResults,
  }) : getAutoCompleteResults =
            getAutoCompleteResults ?? autoCompleteResultsFor;

  final AutoCompleteResultsFunction getAutoCompleteResults;

  static const _evalFieldHeight = 32.0;

  @override
  ExpressionEvalFieldState createState() => ExpressionEvalFieldState();
}

@visibleForTesting
class ExpressionEvalFieldState extends State<ExpressionEvalField>
    with AutoDisposeMixin, SearchFieldMixin<ExpressionEvalField> {
  static final evalTextFieldKey = GlobalKey(debugLabel: 'evalTextFieldKey');

  final _autoCompleteController = AutoCompleteController(evalTextFieldKey);

  int historyPosition = -1;

  String _activeWord = '';

  List<String> _matches = [];

  SearchTextEditingController get searchTextFieldController =>
      _autoCompleteController.searchTextFieldController;

  @override
  SearchControllerMixin get searchController => _autoCompleteController;

  @override
  void initState() {
    super.initState();

    serviceConnection.consoleService.ensureServiceInitialized();

    addAutoDisposeListener(_autoCompleteController.searchNotifier, () {
      _autoCompleteController.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: evalTextFieldKey,
        onTap: _onSelection,
        bottom: false,
        maxWidth: false,
      );
    });
    addAutoDisposeListener(
      _autoCompleteController.selectTheSearchNotifier,
      _handleSearchTermSelected,
    );
    addAutoDisposeListener(
      _autoCompleteController.searchNotifier,
      _handleSearch,
    );

    addAutoDisposeListener(
      _autoCompleteController.currentSuggestion,
      _handleSuggestionTextChange,
    );

    addAutoDisposeListener(
      _autoCompleteController.currentHoveredIndex,
      _handleHoverChange,
    );
  }

  bool _isRealVariableNameOrField(EditingParts parts) {
    return parts.activeWord.isNotEmpty || parts.isField;
  }

  void _handleHoverChange() {
    final editingParts = _currentEditingParts();

    if (!_isRealVariableNameOrField(editingParts)) {
      return;
    }

    _autoCompleteController.updateCurrentSuggestion(_activeWord);
  }

  EditingParts _currentEditingParts() {
    final searchingValue = _autoCompleteController.search;
    final isField = searchingValue.endsWith('.');

    final textFieldEditingValue = searchTextFieldController.value;
    final selection = textFieldEditingValue.selection;

    return AutoCompleteSearchControllerMixin.activeEditingParts(
      searchingValue,
      selection,
      handleFields: isField,
    );
  }

  void _handleSuggestionTextChange() {
    if (searchTextFieldController.isAtEnd) {
      // Only when the cursor is at the end of the text field, we update the
      // `suggestionText` displayed at the end of the text field.

      searchTextFieldController.suggestionText =
          _autoCompleteController.currentSuggestion.value;
    } else {
      searchTextFieldController.suggestionText = null;
    }
  }

  void _handleSearchTermSelected() {
    _autoCompleteController.clearCurrentSuggestion();
  }

  Future<void> _handleSearch() async {
    final searchingValue = _autoCompleteController.search;

    _autoCompleteController.clearCurrentSuggestion();

    if (searchingValue.isNotEmpty) {
      if (_autoCompleteController.selectTheSearch) return;

      // We avoid clearing the list of possible matches here even though the
      // current matches may be out of date as clearing results in flicker
      // as Flutter will render a frame before the new matches are available.

      // Find word in TextField to try and match (word breaks).
      final parts = _currentEditingParts();

      // Only show pop-up if there's a real variable name or field.
      if (!_isRealVariableNameOrField(parts)) {
        _autoCompleteController.clearSearchAutoComplete();
        return;
      }

      // Update the current suggestion without waiting for the results to
      // to prevent flickering of the suggestion text.
      _autoCompleteController.updateCurrentSuggestion(parts.activeWord);

      final matches =
          parts.activeWord.startsWith(_activeWord) && _activeWord.isNotEmpty
              ? _filterMatches(_matches, parts.activeWord)
              : await widget.getAutoCompleteResults(parts, evalService);

      _matches = matches;
      _activeWord = parts.activeWord;

      if (matches.length == 1 && matches.first == parts.activeWord) {
        // It is not useful to show a single autocomplete that is exactly what
        // they already typed.
        _autoCompleteController
          ..clearSearchAutoComplete()
          ..clearCurrentSuggestion();
      } else {
        final results = matches
            .sublist(
              0,
              min(defaultTopMatchesLimit, matches.length),
            )
            .map((match) => AutoCompleteMatch(match))
            .toList();

        _autoCompleteController
          ..searchAutoComplete.value = results
          ..setCurrentHoveredIndexValue(0)
          ..updateCurrentSuggestion(parts.activeWord);
      }
    } else {
      _autoCompleteController.closeAutoCompleteOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('>'),
        const SizedBox(width: denseSpacing),
        Expanded(
          child: Focus(
            onKeyEvent: (_, event) {
              if (!event.isKeyDownOrRepeat) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _historyNavUp();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _historyNavDown();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                _handleExpressionEval(context);
                return KeyEventResult.handled;
              }

              return KeyEventResult.ignored;
            },
            child: SizedBox(
              height: ExpressionEvalField._evalFieldHeight,
              child: AutoCompleteSearchField(
                controller: _autoCompleteController,
                searchFieldEnabled: true,
                shouldRequestFocus: false,
                clearFieldOnEscapeWhenOverlayHidden: true,
                onSelection: _onSelection,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(denseSpacing),
                  border: const OutlineInputBorder(),
                  focusedBorder:
                      const OutlineInputBorder(borderSide: BorderSide.none),
                  enabledBorder:
                      const OutlineInputBorder(borderSide: BorderSide.none),
                  labelText: 'Eval. Enter "?" for help.',
                  labelStyle: Theme.of(context).subtleTextStyle,
                ),
                overlayXPositionBuilder:
                    (String inputValue, TextStyle? inputStyle) {
                  // X-coordinate is equivalent to the width of the input text
                  // up to the last "." or the insertion point (cursor):
                  final indexOfDot = inputValue.lastIndexOf('.');
                  final textSegment = indexOfDot != -1
                      ? inputValue.substring(0, indexOfDot + 1)
                      : inputValue;
                  return calculateTextSpanWidth(
                    TextSpan(
                      text: textSegment,
                      style: inputStyle,
                    ),
                  );
                },
                // Disable ligatures, so the suggestions of the auto complete work correcly.
                style: Theme.of(context).fixedFontStyle.copyWith(
                  fontFeatures: [
                    const FontFeature.disable('liga'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onSelection(String word) {
    setState(() {
      _replaceActiveWord(word);
      _autoCompleteController
        ..selectTheSearch = false
        ..closeAutoCompleteOverlay()
        ..clearCurrentSuggestion();
    });
  }

  /// Replace the current activeWord (partial name) with the selected item from
  /// the auto-complete list.
  void _replaceActiveWord(String word) {
    final textFieldEditingValue = searchTextFieldController.value;
    final editingValue = textFieldEditingValue.text;
    final selection = textFieldEditingValue.selection;

    final parts = AutoCompleteSearchControllerMixin.activeEditingParts(
      editingValue,
      selection,
      handleFields: _autoCompleteController.search.endsWith('.'),
    );

    // Add the newly selected auto-complete value.
    final newValue = '${parts.leftSide}$word${parts.rightSide}';

    // Update the value and caret position of the auto-completed word.
    searchTextFieldController.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.fromPosition(
        // Update the caret position to just beyond the newly picked
        // auto-complete item.
        TextPosition(offset: parts.leftSide.length + word.length),
      ),
    );
  }

  List<String> _filterMatches(
    List<String> previousMatches,
    String activeWord,
  ) {
    return previousMatches
        .where((match) => match.startsWith(activeWord))
        .toList();
  }

  void _handleExpressionEval(BuildContext context) async {
    final expressionText = searchTextFieldController.value.text.trim();
    _autoCompleteController
      ..updateSearchField(newValue: '', caretPosition: 0)
      ..clearSearchField(force: true);

    if (expressionText.isEmpty) return;

    if (expressionText.trim() == '?') {
      ga.select(gac.console, gac.ConsoleEvent.helpInline);
      unawaited(
        showDialog(
          context: context,
          builder: (context) => const ConsoleHelpDialog(),
        ),
      );
      return;
    }

    serviceConnection.consoleService.appendStdio('> $expressionText\n');
    setState(() {
      historyPosition = -1;
      serviceConnection.appState.evalHistory.pushEvalHistory(expressionText);
    });

    try {
      final isolateRef =
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value;

      // Response is either a ErrorRef, InstanceRef, or Sentinel.
      final Response response;
      if (evalService.isStoppedAtDartFrame) {
        ga.select(gac.console, gac.ConsoleEvent.evalInStoppedApp);
        response = await evalService.evalAtCurrentFrame(expressionText);
      } else {
        ga.select(gac.console, gac.ConsoleEvent.evalInRunningApp);
        if (_tryProcessAssignment(expressionText)) return;
        if (isolateRef == null) {
          _emitToConsole(
            'Cannot evaluate expression because the selected isolate is null.',
          );
          return;
        }
        response =
            await evalService.evalInRunningApp(isolateRef, expressionText);
      }

      // Display the response to the user.
      if (response is InstanceRef) {
        _emitRefToConsole(response, isolateRef);
      } else {
        String? value = response.toString();

        if (response is ErrorRef) {
          value = response.message;
        } else if (response is Sentinel) {
          value = response.valueAsString;
        }

        _emitToConsole(value!);
      }
    } catch (e) {
      // Display the error to the user.
      _emitToConsole('$e');
    }
  }

  void _emitToConsole(String text) {
    serviceConnection.consoleService.appendStdio(
      '  ${text.replaceAll('\n', '\n  ')}\n',
    );
  }

  void _emitRefToConsole(
    InstanceRef ref,
    IsolateRef? isolate,
  ) {
    serviceConnection.consoleService.appendInstanceRef(
      value: ref,
      diagnostic: null,
      isolateRef: isolate,
      forceScrollIntoView: true,
    );
  }

  @override
  void dispose() {
    _autoCompleteController.dispose();
    super.dispose();
  }

  EvalHistory get _evalHistory => serviceConnection.appState.evalHistory;

  void _historyNavUp() {
    if (!_evalHistory.canNavigateUp) {
      return;
    }

    setState(() {
      _evalHistory.navigateUp();

      final text = _evalHistory.currentText ?? '';
      searchTextFieldController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _historyNavDown() {
    if (!_evalHistory.canNavigateDown) {
      return;
    }

    setState(() {
      _evalHistory.navigateDown();

      final text = _evalHistory.currentText ?? '';
      searchTextFieldController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  /// If [expressionText] is assignment like `var x=$1`, processes it.
  ///
  /// Returns true if the text was parsed as assignment.
  bool _tryProcessAssignment(String expressionText) {
    final assignment = ConsoleVariableAssignment.tryParse(expressionText);
    if (assignment == null) return false;
    const kSuccess = true;

    if (!evalService.isScopeSupported(emitWarningToConsole: true)) {
      return kSuccess;
    }

    final variable = serviceConnection.consoleService
        .itemAt(assignment.consoleItemIndex + 1);
    final value = variable?.value;
    if (value is! InstanceRef) {
      _emitToConsole(
        'Item #${assignment.consoleItemIndex} cannot be assigned to a variable.',
      );
      return kSuccess;
    }

    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value?.id;
    final isolateName = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value?.name;

    if (isolateId == null || isolateName == null) {
      _emitToConsole(
        'Selected isolate cannot be detected.',
      );
      return kSuccess;
    }

    evalService.scope.add(isolateId, assignment.variableName, value);

    _emitToConsole(
      'Variable ${assignment.variableName} is created and now can be used '
      'in expressions for the isolate "$isolateName".',
    );

    return kSuccess;
  }
}
