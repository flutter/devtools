// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app_shared/utils.dart';
import 'package:vm_service/vm_service.dart';

import '../../connected_app.dart';
import '../../globals.dart';
import '../../ui/search.dart';
import 'eval_service.dart';

AppState get _appState => serviceConnection.appState;

Future<List<String>> autoCompleteResultsFor(
  EditingParts parts,
  EvalService evalService,
) async {
  final result = <String>{};
  if (!parts.isField) {
    final variables = _appState.variables.value;
    result.addAll(variables.map((variable) => variable.name).nonNulls);

    final thisVariable = variables.firstWhereOrNull(
      (variable) => variable.name == 'this',
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
          evalService,
        );
        final classRef = thisValue.classRef;
        if (classRef != null) {
          result.addAll(
            await _autoCompleteMembersFor(
              classRef,
              evalService,
              staticContext: true,
            ),
          );
        }
      }
    }
    final frame = _appState.currentFrame.value;
    if (frame != null) {
      final function = frame.function;
      if (function != null) {
        final libraryRef = await evalService.findOwnerLibrary(function);
        if (libraryRef != null) {
          result.addAll(
            await libraryMemberAndImportsAutocompletes(
              libraryRef,
              evalService,
            ),
          );
        }
      }
    }
  } else {
    var left = parts.leftSide.split(' ').last;
    // Removing trailing `.`.
    left = left.substring(0, left.length - 1);
    try {
      final response = await evalService.evalAtCurrentFrame(left);
      if (response is InstanceRef) {
        final typeClass = response.typeClass;
        if (typeClass != null) {
          // Assume we want static members for a type class not members of the
          // Type object. This is reasonable as Type objects are rarely useful
          // in Dart and we will end up with accidental Type objects if the user
          // writes `SomeClass.` in the evaluate window.
          result.addAll(
            await _autoCompleteMembersFor(
              typeClass,
              evalService,
              staticContext: true,
            ),
          );
        } else {
          await _addAllInstanceMembersToAutocompleteList(
            result,
            response,
            evalService,
          );
        }
      }
    } catch (_) {}
  }
  return result.nonNulls
      .where((name) => name.startsWith(parts.activeWord))
      .toList();
}

// Due to https://github.com/dart-lang/sdk/issues/46221
// we cannot tell what the show clause for an export was so it is unsafe to
// surface exports as if they were library members as there tend to be
// significant false positives for libraries such as Flutter where all of
// dart:ui shows up as in scope from flutter:foundation when it should not be.
bool debugIncludeExports = true;

Future<Set<String>> libraryMemberAndImportsAutocompletes(
  LibraryRef libraryRef,
  EvalService evalService,
) async {
  final autocompletes =
      await _appState.cache.libraryMemberAndImportsAutocomplete.putIfAbsent(
    libraryRef,
    () => _libraryMemberAndImportsAutocompletes(libraryRef, evalService),
  );

  return autocompletes.nonNulls.toSet();
}

Future<Set<String>> _libraryMemberAndImportsAutocompletes(
  LibraryRef libraryRef,
  EvalService evalService,
) async {
  final result = <String>{};
  try {
    final List<Future<Set<String>>> futures = <Future<Set<String>>>[];
    futures.add(
      libraryMemberAutocompletes(
        evalService,
        libraryRef,
        includePrivates: true,
      ),
    );

    final Library library = await evalService.getObject(libraryRef) as Library;
    final dependencies = library.dependencies;

    if (dependencies != null) {
      for (final dependency in library.dependencies!) {
        final prefix = dependency.prefix;
        final target = dependency.target;
        if (prefix != null && prefix.isNotEmpty) {
          // We won't give a list of autocompletes once you enter a prefix
          // but at least we do include the prefix in the autocompletes list.
          result.add(prefix);
        } else if (target != null) {
          futures.add(
            libraryMemberAutocompletes(
              evalService,
              target,
              includePrivates: false,
            ),
          );
        }
      }
    }
    (await Future.wait(futures)).forEach(result.addAll);
  } catch (_) {
    // Silently skip library completions if there is a failure.
  }
  return result;
}

Future<Set<String>> libraryMemberAutocompletes(
  EvalService evalService,
  LibraryRef libraryRef, {
  required bool includePrivates,
}) async {
  var result = (await _appState.cache.libraryMemberAutocomplete.putIfAbsent(
    libraryRef,
    () => _libraryMemberAutocompletes(evalService, libraryRef),
  ))
      .nonNulls;
  if (!includePrivates) {
    result = result.where((name) => !isPrivateMember(name));
  }
  return result.toSet();
}

Future<Set<String>> _libraryMemberAutocompletes(
  EvalService evalService,
  LibraryRef libraryRef,
) async {
  final result = <String>{};
  final Library library = await evalService.getObject(libraryRef) as Library;
  final variables = library.variables;
  if (variables != null) {
    final fields = variables.map((field) => field.name);
    result.addAll(fields.nonNulls);
  }
  final functions = library.functions;
  if (functions != null) {
    // The VM shows setters as `<member>=`.
    final members =
        functions.map((funcRef) => funcRef.name!.replaceAll('=', ''));
    result.addAll(members.nonNulls);
  }
  final classes = library.classes;
  if (classes != null) {
    // Autocomplete class names as well
    final classNames = classes.map((clazz) => clazz.name);
    result.addAll(classNames.nonNulls);
  }

  if (debugIncludeExports) {
    final List<Future<Set<String>>> futures = <Future<Set<String>>>[];
    for (final dependency in library.dependencies!) {
      if (!dependency.isImport!) {
        final prefix = dependency.prefix;
        final target = dependency.target;
        if (prefix != null && prefix.isNotEmpty) {
          result.add(prefix);
        } else if (target != null) {
          futures.add(
            libraryMemberAutocompletes(
              evalService,
              target,
              includePrivates: false,
            ),
          );
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
  EvalService controller,
) async {
  final Instance instance = await controller.getObject(response) as Instance;
  final classRef = instance.classRef;
  if (classRef == null) return;
  result.addAll(
    await _autoCompleteMembersFor(
      classRef,
      controller,
      staticContext: false,
    ),
  );
  // TODO(grouma) - This shouldn't be necessary but package:dwds does
  // not properly provide superclass information.
  final fields = instance.fields;
  if (fields == null) return;
  final clazz = await controller.classFor(classRef);
  final fieldNames = fields
      .where((field) => field.decl?.isStatic != null && !field.decl!.isStatic!)
      .map((field) => field.decl?.name);
  result.addAll(
    fieldNames.nonNulls.where(
      (member) => _isAccessible(member, clazz),
    ),
  );
}

Future<Set<String>> _autoCompleteMembersFor(
  ClassRef classRef,
  EvalService controller, {
  required bool staticContext,
}) async {
  final result = <String>{};
  final clazz = await controller.classFor(classRef);
  if (clazz != null) {
    final fields = clazz.fields;
    if (fields != null) {
      final fieldNames = fields
          .where((f) => f.isStatic == staticContext)
          .map((field) => field.name);
      result.addAll(fieldNames.nonNulls);
    }

    final functions = clazz.functions;
    if (functions != null) {
      for (final funcRef in functions) {
        if (_validFunction(funcRef, clazz, staticContext)) {
          final isConstructor = _isConstructor(funcRef, clazz);
          final funcName = funcRef.name;
          if (funcName == null) continue;
          // The VM shows setters as `<member>=`.
          var name = funcName.replaceAll('=', '');
          if (isConstructor) {
            final clazzName = clazz.name!;
            assert(name.startsWith(clazzName));
            if (name.length <= clazzName.length + 1) continue;
            name = name.substring(clazzName.length + 1);
          }
          result.add(name);
        }
      }
    }
    final superClass = clazz.superClass;
    if (!staticContext && superClass != null) {
      result.addAll(
        await _autoCompleteMembersFor(
          superClass,
          controller,
          staticContext: staticContext,
        ),
      );
    }
    result.removeWhere((member) => !_isAccessible(member, clazz));
  }
  return result;
}

bool _validFunction(FuncRef funcRef, Class clazz, bool staticContext) {
  // TODO(jacobr): we should include named constructors in static contexts.
  return ((_isConstructor(funcRef, clazz) || funcRef.isStatic!) ==
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
    funcRef.name == clazz.name || funcRef.name!.startsWith('${clazz.name}.');

bool _isAccessible(
  String member,
  Class? clazz,
) {
  final frame = _appState.currentFrame.value!;
  final currentScript = frame.location!.script;
  return !isPrivateMember(member) ||
      currentScript!.id == clazz?.location?.script?.id;
}
