// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../service/vm_service_wrapper.dart';
import '../../globals.dart';
import '../../object_tree.dart';
import '../../primitives/auto_dispose.dart';
import '../primitives/eval_history.dart';

class AutocompleteCache {
  final classes = <ClassRef, Class>{};

  /// Cache of autocomplete matches for a library for code written within that
  /// library.
  ///
  /// This cache includes autocompletes from all libraries imported and exported
  /// by the library as well as all private autocompletes for the library.
  final libraryMemberAndImportsAutocomplete =
      <LibraryRef, Future<Set<String?>>>{};

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.
  final libraryMemberAutocomplete = <LibraryRef, Future<Set<String?>>>{};

  void _clear() {
    classes.clear();
    libraryMemberAndImportsAutocomplete.clear();
    libraryMemberAutocomplete.clear();
  }
}

class EvalService extends DisposableController with AutoDisposeControllerMixin {
  EvalService({
    required this.isolateRef,
    required this.variables,
    required this.frameForEval,
    required this.isPaused,
  }) {
    addAutoDisposeListener(isolateRef, () => cache._clear());
  }

  final ValueListenable<IsolateRef?> isolateRef;

  final ValueListenable<bool> isPaused;

  final Frame? Function() frameForEval;

  final ValueListenable<List<DartObjectNode>> variables;

  final EvalHistory evalHistory = EvalHistory();

  final cache = AutocompleteCache();

  String get _isolateRefId {
    final id = isolateRef.value?.id;
    // TODO(polina-c): it is not clear why returning '' is ok.
    if (id == null) return '';
    return id;
  }

  /// Returns the class for the provided [ClassRef].
  ///
  /// May return null.
  Future<Class?> classFor(ClassRef classRef) async {
    try {
      return cache.classes[classRef] ??= await getObject(classRef) as Class;
    } catch (_) {}
    return null;
  }

  /// Find the owner library for a ClassRef, FuncRef, or LibraryRef.
  ///
  /// If Dart had union types, ref would be type ClassRef | FuncRef | LibraryRef
  Future<LibraryRef?> findOwnerLibrary(Object? ref) async {
    if (ref is LibraryRef) {
      return ref;
    }
    if (ref is ClassRef) {
      if (ref.library != null) {
        return ref.library;
      }
      // Fallback for older VMService versions.
      final clazz = await classFor(ref);
      return clazz?.library;
    }
    if (ref is FuncRef) {
      return findOwnerLibrary(ref.owner);
    }
    return null;
  }

  VmServiceWrapper get _service {
    return serviceManager.service!;
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return _service.getObject(_isolateRefId, objRef.id!);
  }

  /// Evaluate the given expression in the context of the currently selected
  /// stack frame, or the top frame if there is no current selection.
  ///
  /// This will fail if the application is not currently paused.
  Future<Response> evalAtCurrentFrame(String expression) {
    if (!isPaused.value) {
      return Future.error(
        RPCError.withDetails(
          'evaluateInFrame',
          RPCError.kInvalidParams,
          'Isolate not paused',
        ),
      );
    }

    final frame = frameForEval();

    if (frame == null) {
      return Future.error(
        RPCError.withDetails(
          'evaluateInFrame',
          RPCError.kInvalidParams,
          'No frames available',
        ),
      );
    }

    return _service.evaluateInFrame(
      _isolateRefId,
      frame.index!,
      expression,
      disableBreakpoints: true,
    );
  }
}
