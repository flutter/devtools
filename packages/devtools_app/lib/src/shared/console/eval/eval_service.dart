// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

import '../../../service/vm_service_wrapper.dart';
import '../../globals.dart';
import '../../memory/adapted_heap_data.dart';
import '../../primitives/auto_dispose.dart';
import '../../vm_utils.dart';
import '../primitives/scope.dart';

class EvalService extends DisposableController with AutoDisposeControllerMixin {
  /// Parameter `scope` for `serviceManager.service!.evaluate(...)`.
  final scope = EvalScope();

  VmServiceWrapper get _service {
    return serviceManager.service!;
  }

  String? get _isolateRefId {
    return serviceManager.isolateManager.selectedIsolate.value?.id;
  }

  /// Returns the class for the provided [ClassRef].
  ///
  /// May return null.
  Future<Class?> classFor(ClassRef classRef) async {
    try {
      return serviceManager.appState.cache.classes[classRef] ??=
          await getObject(classRef) as Class;
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

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj?> getObject(ObjRef objRef) async {
    final ref = _isolateRefId;
    if (ref == null) return Future.value();
    return await _service.getObject(ref, objRef.id!);
  }

  /// Evaluates the expression in the isolate's root library.
  Future<Response> evalInRunningApp(
    IsolateRef isolateRef,
    String expressionText,
  ) async {
    final isolate = serviceManager.isolateManager.isolateState(isolateRef);

    final isolateId = isolateRef.id!;

    final scope = await _scopeIfSupported(isolateId);

    Future<Response> eval() async => await serviceManager.service!.evaluate(
          isolateId,
          (await isolate.isolate)!.rootLib!.id!,
          expressionText,
          scope: scope,
        );

    return await _evalWithVariablesRefresh(eval, isolateId);
  }

  Future<Response> _evalWithVariablesRefresh(
    Future<Response> Function() evalFunction,
    String isolateId,
  ) async {
    try {
      return await evalFunction();
    } on RPCError catch (e) {
      const expressionCompilationErrorCode = 113;
      if (e.code != expressionCompilationErrorCode) rethrow;
      final shouldRetry = await scope.refreshRefs(isolateId);
      _showScopeChangeMessageIfNeeded();
      if (shouldRetry) {
        return await evalFunction();
      } else {
        rethrow;
      }
    }
  }

  void _showScopeChangeMessageIfNeeded() {
    if (scope.removedVariables.isEmpty) return;
    final variables = scope.removedVariables.join(', ');
    serviceManager.consoleService.appendStdio(
      'Garbage collected instances were removed from the scope: $variables. '
      'Pause application (use DevTools > Debugger) to make the variables persistent.\n',
    );
  }

  bool get isStoppedAtDartFrame {
    return serviceManager.isMainIsolatePaused &&
        serviceManager.appState.currentFrame.value?.code?.kind ==
            CodeKind.kDart;
  }

  /// Evaluate the given expression in the context of the currently selected
  /// stack frame, or the top frame if there is no current selection.
  ///
  /// This will fail if the application is not currently paused.
  Future<Response> evalAtCurrentFrame(String expression) async {
    final appState = serviceManager.appState;

    if (!serviceManager.isMainIsolatePaused) {
      return Future.error(
        RPCError.withDetails(
          'evaluateInFrame',
          RPCError.kInvalidParams,
          'Isolate not paused',
        ),
      );
    }

    final frame = appState.currentFrame.value;

    if (frame == null) {
      return Future.error(
        RPCError.withDetails(
          'evaluateInFrame',
          RPCError.kInvalidParams,
          'No frames available',
        ),
      );
    }

    final isolateRefId = _isolateRefId;

    if (isolateRefId == null) {
      return Future.error(
        RPCError.withDetails(
          'evaluateInFrame',
          RPCError.kServerError,
          'isolateRefId is null',
        ),
      );
    }

    final scope = await _scopeIfSupported(isolateRefId);

    Future<Response> evalFunction() => _service.evaluateInFrame(
          isolateRefId,
          frame.index!,
          expression,
          disableBreakpoints: true,
          scope: scope,
        );

    return await _evalWithVariablesRefresh(evalFunction, isolateRefId);
  }

  Future<Map<String, String>?> _scopeIfSupported(String isolateRefId) async {
    // Debugging for web does not support scopes yet.
    if (await serviceManager.connectedApp?.isDartWebApp ?? true) return null;

    return scope.value(isolateId: isolateRefId);
  }

  Future<InstanceRef?> findObject(
    AdaptedHeapObject object,
    IsolateRef isolateRef,
  ) async {
    final isolateId = isolateRef.id!;

    final theClass = (await serviceManager.service!.getClassList(isolateId))
        .classes!
        .firstWhereOrNull((ref) => object.heapClass.matches(ref));

    return await findInstance(isolateId, theClass?.id, object.code);
  }
}
