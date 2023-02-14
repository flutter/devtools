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

class EvalService extends DisposableController with AutoDisposeControllerMixin {
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

    return _service.evaluateInFrame(
      isolateRefId,
      frame.index!,
      expression,
      disableBreakpoints: true,
    );
  }

  Future<InstanceRef?> findObject(
    AdaptedHeapObject object,
    IsolateRef isolateRef,
  ) async {
    final isolateId = isolateRef.id!;

    final theClass = (await serviceManager.service!.getClassList(isolateId))
        .classes!
        .firstWhere((ref) => object.heapClass.matches(ref));

    final instances = await serviceManager.service!.getInstances(
      isolateId,
      theClass.id!,
      preferences.memory.refLimit.value,
    );

    return (instances.instances ?? const []).firstWhereOrNull(
      (i) => i is InstanceRef && i.identityHashCode == object.code,
    ) as InstanceRef?;
  }
}
