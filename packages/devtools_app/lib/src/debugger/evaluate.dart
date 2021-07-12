// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../globals.dart';
import '../notifications.dart';
import '../theme.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'debugger_controller.dart';

class ExpressionEvalField extends StatefulWidget {
  const ExpressionEvalField({
    @required this.controller,
  });

  final DebuggerController controller;

  @override
  _ExpressionEvalFieldState createState() => _ExpressionEvalFieldState();
}

class _ExpressionEvalFieldState extends State<ExpressionEvalField>
    with SearchFieldMixin, AutoDisposeMixin {
  AutoCompleteController _autoCompleteController;
  int historyPosition = -1;

  final evalTextFieldKey = GlobalKey(debugLabel: 'evalTextFieldKey');

  @override
  void initState() {
    super.initState();

    _autoCompleteController = AutoCompleteController();

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

      // We avoid clearing the list of possible matches here even though the
      // current matches may be out of date as clearing results in flicker
      // as Flutter will render a frame before the new matches are available.

      // Find word in TextField to try and match (word breaks).
      final textFieldEditingValue = searchTextFieldController.value;
      final selection = textFieldEditingValue.selection;

      final parts = AutoCompleteSearchControllerMixin.activeEdtingParts(
        searchingValue,
        selection,
        handleFields: isField,
      );

      // Only show pop-up if there's a real variable name or field.
      if (parts.activeWord.isEmpty && !parts.isField) {
        _autoCompleteController.clearSearchAutoComplete();
        return;
      }
      final matches = await autoCompleteResultsFor(parts, widget.controller);
      if (matches.length == 1 && matches.first == parts.activeWord) {
        // It is not useful to show a single autocomplete that is exactly what
        // the already typed.
        _autoCompleteController.clearSearchAutoComplete();
      } else {
        _autoCompleteController.searchAutoComplete.value = matches.sublist(
          0,
          min(defaultTopMatchesLimit, matches.length),
        );
        _autoCompleteController.currentDefaultIndex = 0;
      }
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
                  focusedBorder:
                      OutlineInputBorder(borderSide: BorderSide.none),
                  enabledBorder:
                      OutlineInputBorder(borderSide: BorderSide.none),
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

  void _handleExpressionEval() async {
    final expressionText = searchTextFieldController.value.text.trim();
    updateSearchField(_autoCompleteController, '', 0);
    clearSearchField(_autoCompleteController, force: true);

    if (expressionText.isEmpty) return;

    // Only try to eval if we are paused.
    if (!serviceManager
        .isolateManager.mainIsolateDebuggerState.isPaused.value) {
      Notifications.of(context)
          .push('Application must be paused to support expression evaluation.');
      return;
    }

    serviceManager.consoleService.appendStdio('> $expressionText\n');
    setState(() {
      historyPosition = -1;
      widget.controller.evalHistory.pushEvalHistory(expressionText);
    });

    try {
      // Response is either a ErrorRef, InstanceRef, or Sentinel.
      final isolateRef = widget.controller.isolateRef;
      final response =
          await widget.controller.evalAtCurrentFrame(expressionText);

      // Display the response to the user.
      if (response is InstanceRef) {
        _emitRefToConsole(response, isolateRef);
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
    serviceManager.consoleService.appendStdio(
      '  ${text.replaceAll('\n', '\n  ')}\n',
      forceScrollIntoView: true,
    );
  }

  void _emitRefToConsole(
    InstanceRef ref,
    IsolateRef isolate,
  ) {
    serviceManager.consoleService.appendInstanceRef(
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
    final variables = controller.variables.value;
    result.addAll(variables.map((variable) => variable.name));

    final thisVariable = variables.firstWhere(
      (variable) => variable.name == 'this',
      orElse: () => null,
    );
    if (thisVariable != null) {
      // If a variable named `this` is in scope, we should provide autocompletes
      // for all static and instance members of that class as they are in scope
      // in Dart. For example, if you evaluate `foo()` that will be equivalent
      // to `this.foo()` if foo is an instance member and `ThisClass.foo() if
      // foo is a static member.
      final thisValue = thisVariable.value;
      if (thisValue is InstanceRef) {
        await _addAllInstanceMembersToAutocompleteList(
          result,
          thisValue,
          controller,
        );
        result.addAll(await _autoCompleteMembersFor(
          thisValue.classRef,
          controller,
          staticContext: true,
        ));
      }
    }
    final frame = controller.frameForEval;
    if (frame != null) {
      final function = frame.function;
      if (function != null) {
        final libraryRef = await controller.findOwnerLibrary(function);
        if (libraryRef != null) {
          result.addAll(await libraryMemberAndImportsAutocompletes(
              libraryRef, controller));
        }
      }
    }
  } else {
    var left = parts.leftSide.split(' ').last;
    // Removing trailing `.`.
    left = left.substring(0, left.length - 1);
    try {
      final response = await controller.evalAtCurrentFrame(left);
      if (response is InstanceRef) {
        if (response.typeClass != null) {
          // Assume we want static members for a type class not members of the
          // Type object. This is reasonable as Type objects are rarely useful
          // in Dart and we will end up with accidental Type objects if the user
          // writes `SomeClass.` in the evaluate window.
          result.addAll(await _autoCompleteMembersFor(
            response.typeClass,
            controller,
            staticContext: true,
          ));
        } else {
          await _addAllInstanceMembersToAutocompleteList(
            result,
            response,
            controller,
          );
        }
      }
    } catch (_) {}
  }
  return result.where((name) => name.startsWith(parts.activeWord)).toList();
}

// Due to https://github.com/dart-lang/sdk/issues/46221
// we cannot tell what the show clause for an export was so it is unsafe to
// surface exports as if they were library members as there tend to be
// significant false positives for libraries such as Flutter where all of
// dart:ui shows up as in scope from flutter:foundation when it should not be.
bool debugIncludeExports = true;

Future<Set<String>> libraryMemberAndImportsAutocompletes(
  LibraryRef libraryRef,
  DebuggerController controller,
) {
  return controller.libraryMemberAndImportsAutocompleteCache.putIfAbsent(
    libraryRef,
    () => _libraryMemberAndImportsAutocompletes(libraryRef, controller),
  );
}

Future<Set<String>> _libraryMemberAndImportsAutocompletes(
  LibraryRef libraryRef,
  DebuggerController controller,
) async {
  final result = <String>{};
  try {
    final futures = <Future<Set<String>>>[];
    futures.add(libraryMemberAutocompletes(
      controller,
      libraryRef,
      includePrivates: true,
    ));

    final Library library = await controller.getObject(libraryRef);
    for (var dependency in library.dependencies) {
      if (dependency.prefix?.isNotEmpty ?? false) {
        // We won't give a list of autocompletes once you enter a prefix
        // but at least we do include the prefix in the autocompletes list.
        result.add(dependency.prefix);
      } else {
        futures.add(libraryMemberAutocompletes(
          controller,
          dependency.target,
          includePrivates: false,
        ));
      }
    }
    (await Future.wait(futures)).forEach(result.addAll);
  } catch (_) {
    // Silently skip library completions if there is a failure.
  }
  return result;
}

Future<Set<String>> libraryMemberAutocompletes(
  DebuggerController controller,
  LibraryRef libraryRef, {
  @required bool includePrivates,
}) async {
  var result = await controller.libraryMemberAutocompleteCache.putIfAbsent(
    libraryRef,
    () => _libraryMemberAutocompletes(controller, libraryRef),
  );
  if (!includePrivates) {
    result = result.where((name) => !isPrivate(name)).toSet();
  }
  return result;
}

Future<Set<String>> _libraryMemberAutocompletes(
  DebuggerController controller,
  LibraryRef libraryRef,
) async {
  final result = <String>{};
  final Library library = await controller.getObject(libraryRef);
  result.addAll(library.variables.map((field) => field.name));
  result.addAll(library.functions
      // The VM shows setters as `<member>=`.
      .map((funcRef) => funcRef.name.replaceAll('=', '')));
  // Autocomplete class names as well
  result.addAll(library.classes.map((clazz) => clazz.name));

  if (debugIncludeExports) {
    final futures = <Future<Set<String>>>[];
    for (var dependency in library.dependencies) {
      if (!dependency.isImport) {
        if (dependency.prefix?.isNotEmpty ?? false) {
          result.add(dependency.prefix);
        } else {
          futures.add(libraryMemberAutocompletes(
            controller,
            dependency.target,
            includePrivates: false,
          ));
        }
      }
    }
    if (futures.isNotEmpty) {
      (await Future.wait(futures)).forEach(result.addAll);
    }
  }
  return result;
}

Future<void> _addAllInstanceMembersToAutocompleteList(
  Set<String> result,
  InstanceRef response,
  DebuggerController controller,
) async {
  final Instance instance = await controller.getObject(response);
  result.addAll(
    await _autoCompleteMembersFor(
      instance.classRef,
      controller,
      staticContext: false,
    ),
  );
  // TODO(grouma) - This shouldn't be necessary but package:dwds does
  // not properly provide superclass information.
  final clazz = await controller.classFor(instance.classRef);
  result.addAll(instance.fields
      .where((field) => !field.decl.isStatic)
      .map((field) => field.decl.name)
      .where((member) => _isAccessible(member, clazz, controller)));
}

Future<Set<String>> _autoCompleteMembersFor(
  ClassRef classRef,
  DebuggerController controller, {
  @required bool staticContext,
}) async {
  if (classRef == null) {
    return {};
  }
  // TODO(jacobr): consider using controller.autocompleteCache to cache the list
  // of autocomplete candidates for each class. The main challenge with caching
  // is _isAccessible depends on the current source location so makes caching
  // difficult.
  final result = <String>{};
  final clazz = await controller.classFor(classRef);
  if (clazz != null) {
    result.addAll(clazz.fields
        .where((f) => f.isStatic == staticContext)
        .map((field) => field.name));
    for (var funcRef in clazz.functions) {
      if (_validFunction(funcRef, clazz, staticContext)) {
        final isConstructor = _isConstructor(funcRef, clazz);
        // The VM shows setters as `<member>=`.
        var name = funcRef.name.replaceAll('=', '');
        if (isConstructor) {
          assert(name.startsWith(clazz.name));
          if (name.length <= clazz.name.length + 1) continue;
          name = name.substring(clazz.name.length + 1);
        }
        result.add(name);
      }
    }
    if (!staticContext) {
      result.addAll(await _autoCompleteMembersFor(
        clazz.superClass,
        controller,
        staticContext: staticContext,
      ));
    }
    result.removeWhere((member) => !_isAccessible(member, clazz, controller));
  }
  return result;
}

bool _validFunction(FuncRef funcRef, Class clazz, bool staticContext) {
  // TODO(jacobr): we should include named constructors in static contexts.
  return ((_isConstructor(funcRef, clazz) || funcRef.isStatic) ==
          staticContext) &&
      !_isOperator(funcRef);
}

bool _isOperator(FuncRef funcRef) => const {
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
      'unary-',
    }.contains(funcRef.name);

bool _isConstructor(FuncRef funcRef, Class clazz) =>
    funcRef.name == clazz.name || funcRef.name.startsWith('${clazz.name}.');

bool _isAccessible(String member, Class clazz, DebuggerController controller) {
  final frame = controller.frameForEval;
  final currentScript = frame.location.script;
  return !isPrivate(member) || currentScript.id == clazz?.location?.script?.id;
}
