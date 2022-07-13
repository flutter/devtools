// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
    addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate,
        () async {
      await scriptManager.retrieveAndSortScripts(
        serviceManager.isolateManager.selectedIsolate.value!,
      );
      restartController();
    });

    _objectHistoryListener = () async {
      final currentObjectValue = objectHistory.current.value;
      _currentScriptRef.value = currentObjectValue?.scriptNode;

      if (currentObjectValue != null) {
        await programExplorerController
            .selectScriptNode(currentObjectValue.scriptNode);

        if (objectHistory.current.value?.outlineNode != null) {
          programExplorerController
              .selectOutlineNode(currentObjectValue.outlineNode!);
        } else {
          programExplorerController.resetOutline();
        }
      }
    };

    objectHistory.current.addListener(_objectHistoryListener);
  }

  final programExplorerController = ProgramExplorerController();
  // ..initListeners();

  final objectHistory = ObjectHistory();

  late VoidCallback _objectHistoryListener;

  final _currentScriptRef = ValueNotifier<ScriptRef?>(null);

  ValueListenable<ScriptRef?> get currentScriptRef => _currentScriptRef;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

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
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FuncRef) {
      object = FuncObject(
        ref: objRef,
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FieldRef) {
      object = FieldObject(
        ref: objRef,
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is LibraryRef) {
      object = LibraryObject(
        ref: objRef,
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is ScriptRef) {
      object = ScriptObject(
        ref: objRef,
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is InstanceRef) {
      object = InstanceObject(
        ref: objRef,
        scriptNode: fileExplorerScriptRef,
        outlineNode: outlineSelection,
      );
    }

    await object?.initialize();

    return object;
  }

  void restartController() {
    if (programExplorerController.initialized.value == true) {
      programExplorerController.restart();
    } else {
      programExplorerController.initialize();
    }
    objectHistory.clear();
  }

  void setCurrentScript(ScriptRef scriptRef) {
    _currentScriptRef.value = scriptRef;
  }
}
