// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose.dart';
import '../../shared/globals.dart';
import '../debugger/program_explorer_controller.dart';
import 'object_viewport.dart';
import 'vm_object_model.dart';

/// Stores the state information for the object inspector view related to
/// the object history and the object viewport.
class ObjectInspectorViewController extends DisposableController
    with AutoDisposeControllerMixin {
  ObjectInspectorViewController() {
    // addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate,
    //     () async {
    //   restartController();
    // });

    addAutoDisposeListener(
      scriptManager.sortedScripts,
      selectAndPushMainScript,
    );

    objectHistory.current.addListener(_onCurrentObjectChanged);
  }

  final programExplorerController = ProgramExplorerController()
    ..initialize()
    ..initListeners();

  final objectHistory = ObjectHistory();

  Isolate? isolate;

  final _currentScriptRef = ValueNotifier<ScriptRef?>(null);

  ValueListenable<ScriptRef?> get currentScriptRef => _currentScriptRef;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  Future<void> _onCurrentObjectChanged() async {
    final currentObjectValue = objectHistory.current.value;

    _currentScriptRef.value = currentObjectValue?.scriptRef;

    if (currentObjectValue != null) {
      await programExplorerController
          .selectScriptNode(currentObjectValue.scriptRef);

      if (objectHistory.current.value?.outlineNode != null) {
        programExplorerController
          ..selectOutlineNode(currentObjectValue.outlineNode!)
          ..expandToNode(currentObjectValue.outlineNode!);
      } else {
        programExplorerController.resetOutline();
      }
    }
  }

  Future<void> refreshObject() async {
    _refreshing.value = true;

    final objRef = objectHistory.current.value?.ref;

    if (objRef != null) {
      final refetchedObject = await createVmObject(objRef);
      if (refetchedObject != null) {
        objectHistory.replaceCurrent(refetchedObject);
      }
    }

    _refreshing.value = false;
  }

  Future<void> pushObject(ObjRef objRef) async {
    _refreshing.value = true;

    final object = await createVmObject(objRef);
    if (object != null) {
      objectHistory.pushEntry(object);
    }

    _refreshing.value = false;
  }

  Future<VmObject?> createVmObject(ObjRef objRef) async {
    VmObject? object;

    final fileExplorerScriptRef = currentScriptRef.value;

    final outlineSelection = programExplorerController.outlineSelection.value;

    if (objRef is ClassRef) {
      object = ClassObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FuncRef) {
      object = FuncObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FieldRef) {
      object = FieldObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is LibraryRef) {
      object = LibraryObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is ScriptRef) {
      object = ScriptObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is InstanceRef) {
      object = InstanceObject(
        ref: objRef,
        scriptRef: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    }

    await object?.initialize();

    return object;
  }

  void selectAndPushMainScript() async {
    objectHistory.clear();

    final scriptRefs = scriptManager.sortedScripts.value;

    final service = serviceManager.service!;

    final isolate = await service
        .getIsolate(serviceManager.isolateManager.selectedIsolate.value!.id!);

    final mainScriptRef = scriptRefs.firstWhereOrNull((ref) {
      return ref.uri == isolate.rootLib?.uri;
    });

    if (mainScriptRef != null) {
      _currentScriptRef.value = mainScriptRef;

      final parts = mainScriptRef.uri!.split('/')..removeLast();

      await programExplorerController.selectScriptNode(mainScriptRef);

      final libraries = isolate.libraries!;

      if (parts.isEmpty) {
        for (final lib in libraries) {
          if (lib.uri == mainScriptRef.uri) {
            return await pushObject(lib);
          }
        }
      }

      await pushObject(mainScriptRef);
    }
  }

  void setCurrentScript(ScriptRef scriptRef) {
    _currentScriptRef.value = scriptRef;
  }
}
