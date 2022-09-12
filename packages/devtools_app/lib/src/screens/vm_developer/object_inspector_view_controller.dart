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
    addAutoDisposeListener(
      scriptManager.sortedScripts,
      selectAndPushMainScript,
    );

    addAutoDisposeListener(
      objectHistory.current,
      _onCurrentObjectChanged,
    );
  }

  final programExplorerController =
      ProgramExplorerController(showCodeNodes: true);

  final objectHistory = ObjectHistory();

  Isolate? isolate;

  ScriptRef? _currentScriptRef;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  bool _initialized = false;

  void init() {
    if (!_initialized) {
      programExplorerController
        ..initialize()
        ..initListeners();
      selectAndPushMainScript();
      _initialized = true;
    }
  }

  Future<void> _onCurrentObjectChanged() async {
    final currentObjectValue = objectHistory.current.value;

    if (currentObjectValue != null) {
      final scriptRef = currentObjectValue.scriptRef ??
          (await programExplorerController
                  .searchFileExplorer(currentObjectValue.obj))
              ?.script;

      if (scriptRef != null) {
        await programExplorerController.selectScriptNode(scriptRef);
      }

      final outlineNode = currentObjectValue.outlineNode ??
          programExplorerController.breadthFirstSearchObject(
            currentObjectValue.obj,
            programExplorerController.outlineNodes.value,
          );

      if (outlineNode != null) {
        programExplorerController
          ..selectOutlineNode(outlineNode)
          ..expandToNode(outlineNode);
      } else {
        programExplorerController.resetOutline();
      }
    } else {
      programExplorerController.resetOutline();
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

    final outlineSelection = programExplorerController.outlineSelection.value;

    if (objRef is ClassRef) {
      object = ClassObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FuncRef) {
      object = FuncObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is FieldRef) {
      object = FieldObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
        outlineNode: outlineSelection,
      );
    } else if (objRef is LibraryRef) {
      object = LibraryObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
      );
    } else if (objRef is ScriptRef) {
      object = ScriptObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
      );
    } else if (objRef is InstanceRef) {
      object = InstanceObject(
        ref: objRef,
      );
    } else if (objRef is CodeRef) {
      object = CodeObject(
        ref: objRef,
        scriptRef: _currentScriptRef,
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
      _currentScriptRef = mainScriptRef;

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
    _currentScriptRef = scriptRef;
  }
}
