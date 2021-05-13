// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../auto_dispose_mixin.dart';
import '../notifications.dart';
import '../theme.dart';
import '../ui/search.dart';
import 'debugger_controller.dart';

class ExpressionEvalField extends StatefulWidget {
  const ExpressionEvalField({
    this.controller,
  });

  final DebuggerController controller;

  @override
  _ExpressionEvalFieldState createState() => _ExpressionEvalFieldState();
}

class _AutoCompleteController extends DisposableController
    with SearchControllerMixin, AutoCompleteSearchControllerMixin {}

class _ExpressionEvalFieldState extends State<ExpressionEvalField>
    with SearchFieldMixin, AutoDisposeMixin {
  _AutoCompleteController _autoCompleteController;
  int historyPosition = -1;

  final evalTextFieldKey = GlobalKey(debugLabel: 'evalTextFieldKey');

  @override
  void initState() {
    super.initState();

    _autoCompleteController = _AutoCompleteController();

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
        _autoCompleteController.selectTheSearchNotifier, _handleSearch);
    addAutoDisposeListener(
        _autoCompleteController.searchNotifier, _handleSearch);
  }

  void _handleSearch() async {
    final searchingValue = _autoCompleteController.search;
    final isField = searchingValue.endsWith('.');

    if (searchingValue.isNotEmpty) {
      if (_autoCompleteController.selectTheSearch) {
        _autoCompleteController.resetSearch();
        return;
      }

      // No exact match, return the list of possible matches.
      _autoCompleteController.clearSearchAutoComplete();

      // Find word in TextField to try and match (word breaks).
      final textFieldEditingValue = searchTextFieldController.value;
      final selection = textFieldEditingValue.selection;

      final parts = AutoCompleteSearchControllerMixin.activeEdtingParts(
        searchingValue,
        selection,
        handleFields: isField,
      );

      // Only show pop-up if there's a real variable name or field.
      if (parts.activeWord.isEmpty && !parts.isField) return;

      final matches = await autoCompleteResultsFor(parts, widget.controller);
      _autoCompleteController.searchAutoComplete.value = matches.sublist(
        0,
        min(defaultTopMatchesLimit, matches.length),
      );
    } else {
      _autoCompleteController.closeAutoCompleteOverlay();
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
          const Text('>'),
          const SizedBox(width: 8.0),
          Expanded(
            child: Focus(
              onKey: (_, RawKeyEvent event) {
                if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
                  _historyNavUp();
                  return KeyEventResult.handled;
                } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                  _historyNavDown();
                  return KeyEventResult.handled;
                } else if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                  _handleExpressionEval();
                  return KeyEventResult.handled;
                }

                return KeyEventResult.ignored;
              },
              child: buildAutoCompleteSearchField(
                controller: _autoCompleteController,
                searchFieldKey: evalTextFieldKey,
                searchFieldEnabled: true,
                shouldRequestFocus: false,
                supportClearField: true,
                onSelection: _onSelection,
                tracking: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(denseSpacing),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: evalBorder),
                  enabledBorder: OutlineInputBorder(borderSide: evalBorder),
                  labelText: 'Eval',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSelection(String word) {
    setState(() {
      _replaceActiveWord(word);
      _autoCompleteController.selectTheSearch = false;
      _autoCompleteController.closeAutoCompleteOverlay();
    });
  }

  /// Replace the current activeWord (partial name) with the selected item from
  /// the auto-complete list.
  void _replaceActiveWord(String word) {
    final textFieldEditingValue = searchTextFieldController.value;
    final editingValue = textFieldEditingValue.text;
    final selection = textFieldEditingValue.selection;

    final parts = AutoCompleteSearchControllerMixin.activeEdtingParts(
      editingValue,
      selection,
      handleFields: _autoCompleteController.isField,
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

  void _handleExpressionEval() async {
    final expressionText = searchTextFieldController.value.text.trim();
    updateSearchField(_autoCompleteController, '', 0);
    clearSearchField(_autoCompleteController, force: true);

    if (expressionText.isEmpty) return;

    // Don't try to eval if we're not paused.
    if (!widget.controller.isPaused.value) {
      Notifications.of(context)
          .push('Application must be paused to support expression evaluation.');
      return;
    }

    widget.controller.appendStdio('> $expressionText\n');
    setState(() {
      historyPosition = -1;
      widget.controller.evalHistory.pushEvalHistory(expressionText);
    });

    try {
      // Response is either a ErrorRef, InstanceRef, or Sentinel.
      final response =
          await widget.controller.evalAtCurrentFrame(expressionText);

      // Display the response to the user.
      if (response is InstanceRef) {
        _emitRefToConsole(response);
      } else {
        var value = response.toString();

        if (response is ErrorRef) {
          value = response.message;
        } else if (response is Sentinel) {
          value = response.valueAsString;
        }

        _emitToConsole(value);
      }
    } catch (e) {
      // Display the error to the user.
      _emitToConsole('$e');
    }
  }

  void _emitToConsole(String text) {
    widget.controller.appendStdio('  ${text.replaceAll('\n', '\n  ')}\n');
  }

  void _emitRefToConsole(InstanceRef ref) {
    widget.controller.appendInstanceRef(ref);
  }

  @override
  void dispose() {
    _autoCompleteController.dispose();
    super.dispose();
  }

  void _historyNavUp() {
    final evalHistory = widget.controller.evalHistory;
    if (!evalHistory.canNavigateUp) {
      return;
    }

    setState(() {
      evalHistory.navigateUp();

      final text = evalHistory.currentText;
      searchTextFieldController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _historyNavDown() {
    final evalHistory = widget.controller.evalHistory;
    if (!evalHistory.canNavigateDown) {
      return;
    }

    setState(() {
      evalHistory.navigateDown();

      final text = evalHistory.currentText ?? '';
      searchTextFieldController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }
}

Future<List<String>> autoCompleteResultsFor(
  EditingParts parts,
  DebuggerController controller,
) async {
  final result = <String>{};
  if (!parts.isField) {
    result.addAll(
        controller.variables.value.map((variable) => variable.boundVar.name));
  } else {
    var left = parts.leftSide.split(' ').last;
    // Removing trailing `.`.
    left = left.substring(0, left.length - 1);
    try {
      final response = await controller.evalAtCurrentFrame(left);
      if (response is InstanceRef) {
        final Instance instance = await controller.getObject(response);
        result.addAll(
          await _autoCompleteMembersFor(
            instance.classRef,
            controller,
          ),
        );
        // TODO(grouma) - This shouldn't be necessary but package:dwds does
        // not properly provide superclass information.
        result.addAll(instance.fields.map((field) => field.decl.name));
      }
    } catch (_) {}
  }
  return result.where((name) => name.startsWith(parts.activeWord)).toList()
    ..sort();
}

Future<List<String>> _autoCompleteMembersFor(
    ClassRef classRef, DebuggerController controller) async {
  final result = <String>[];
  if (classRef != null) {
    final Class clazz = await controller.getObject(classRef);
    result.addAll(clazz.fields.map((field) => field.name));
    result.addAll(clazz.functions
        .where((funcRef) => _validFunction(funcRef, clazz))
        // The VM shows setters as `<member>=`.
        .map((funcRef) => funcRef.name.replaceAll('=', '')));
    result.addAll(await _autoCompleteMembersFor(clazz.superClass, controller));
    result.removeWhere((member) => !_isAccessible(member, clazz, controller));
  }
  return result;
}

bool _validFunction(FuncRef funcRef, Class clazz) {
  return !funcRef.isStatic &&
      !_isContructor(funcRef, clazz) &&
      !_isOperator(funcRef);
}

bool _isOperator(FuncRef funcRef) => [
      '==',
      '+',
      '-',
      '*',
      '/',
      '&',
      '~',
      '|',
      '>',
      '<',
      '>=',
      '<=',
      '>>',
      '<<',
      '>>>',
      '^',
      '%',
      '~/',
      'uniary-',
    ].contains(funcRef.name);

bool _isContructor(FuncRef funcRef, Class clazz) =>
    funcRef.name == clazz.name || funcRef.name.startsWith('${clazz.name}.');

bool _isAccessible(String member, Class clazz, DebuggerController controller) {
  final frame = controller.selectedStackFrame.value?.frame ??
      controller.stackFramesWithLocation.value.first.frame;
  final currentScript = frame.location.script;
  return !(member.startsWith('_') &&
      currentScript.id != clazz.location?.script?.id);
}
