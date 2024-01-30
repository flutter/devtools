// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../debugger/codeview_controller.dart';
import '../../debugger/program_explorer_controller.dart';
import '../vm_service_private_extensions.dart';
import 'class_hierarchy_explorer_controller.dart';
import 'object_store_controller.dart';
import 'object_viewport.dart';
import 'vm_object_model.dart';

/// Stores the state information for the object inspector view related to
/// the object history and the object viewport.
class ObjectInspectorViewController extends DisposableController
    with AutoDisposeControllerMixin {
  ObjectInspectorViewController({
    ClassHierarchyExplorerController? classHierarchyController,
  }) : classHierarchyController =
            classHierarchyController ?? ClassHierarchyExplorerController() {
    addAutoDisposeListener(
      scriptManager.sortedScripts,
      _initializeForCurrentIsolate,
    );

    addAutoDisposeListener(
      objectHistory.current,
      _onCurrentObjectChanged,
    );
  }

  final programExplorerController =
      ProgramExplorerController(showCodeNodes: true);

  final ClassHierarchyExplorerController classHierarchyController;
  final codeViewController = CodeViewController();
  final objectStoreController = ObjectStoreController();

  final objectHistory = ObjectHistory();

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      await programExplorerController.initialize();
      programExplorerController.initListeners();
      _initializeForCurrentIsolate();
      _initialized = true;
    }
  }

  Future<void> _onCurrentObjectChanged() async {
    final currentObjectValue = objectHistory.current.value;

    if (currentObjectValue != null) {
      try {
        final scriptRef = currentObjectValue.scriptRef ??
            (await programExplorerController
                    .searchFileExplorer(currentObjectValue.obj))
                .script;

        if (scriptRef != null) {
          await programExplorerController.selectScriptNode(scriptRef);
        }
      } on StateError {
        // Couldn't find a node for the newly pushed object. It's likely that
        // this is an object from the object store that isn't otherwise
        // reachable from the isolate's libraries, or it's an instance object.
        programExplorerController.clearSelection();
        return;
      }

      final outlineNode = programExplorerController.breadthFirstSearchObject(
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
      final refetchedObject = await createVmObject(
        objRef,
        scriptRef: objectHistory.current.value!.scriptRef,
      );
      if (refetchedObject != null) {
        objectHistory.replaceCurrent(refetchedObject);
      }
    }

    _refreshing.value = false;
  }

  Future<void> pushObject(ObjRef objRef, {ScriptRef? scriptRef}) async {
    _refreshing.value = true;

    final object = await createVmObject(objRef, scriptRef: scriptRef);
    if (object != null) {
      objectHistory.pushEntry(object);
    }

    _refreshing.value = false;
  }

  Future<VmObject?> createVmObject(
    ObjRef objRef, {
    ScriptRef? scriptRef,
  }) async {
    VmObject object;
    if (objRef is ClassRef) {
      object = ClassObject(
        ref: objRef,
        scriptRef: scriptRef,
      );
    } else if (objRef is FuncRef) {
      object = FuncObject(
        ref: objRef,
        scriptRef: scriptRef,
      );
    } else if (objRef is FieldRef) {
      object = FieldObject(
        ref: objRef,
        scriptRef: scriptRef,
      );
    } else if (objRef is LibraryRef) {
      object = LibraryObject(
        ref: objRef,
        scriptRef: scriptRef,
      );
    } else if (objRef is ScriptRef) {
      object = ScriptObject(
        ref: objRef,
        scriptRef: scriptRef,
      );
    } else if (objRef is InstanceRef) {
      object = InstanceObject(
        ref: objRef,
      );
    } else if (objRef is CodeRef) {
      object = CodeObject(
        ref: objRef,
      );
    } else if (objRef.isObjectPool) {
      object = ObjectPoolObject(
        ref: objRef,
      );
    } else if (objRef.isICData) {
      object = ICDataObject(
        ref: objRef,
      );
    } else if (objRef.isSubtypeTestCache) {
      object = SubtypeTestCacheObject(
        ref: objRef,
      );
    } else if (objRef.isWeakArray) {
      object = WeakArrayObject(
        ref: objRef,
      );
    } else {
      object = UnknownObject(
        ref: objRef,
      );
    }

    await object.initialize();

    return object;
  }

  /// Re-initializes the object inspector's state when building it for the
  /// first time or when the selected isolate is updated.
  void _initializeForCurrentIsolate() async {
    objectHistory.clear();
    await objectStoreController.refresh();
    await classHierarchyController.refresh();

    final scriptRefs = scriptManager.sortedScripts.value;
    final service = serviceConnection.serviceManager.service!;
    final isolate = await service.getIsolate(
      serviceConnection
          .serviceManager.isolateManager.selectedIsolate.value!.id!,
    );

    final mainScriptRef = scriptRefs.firstWhereOrNull((ref) {
      return ref.uri == isolate.rootLib?.uri;
    });

    if (mainScriptRef != null) {
      await programExplorerController.selectScriptNode(mainScriptRef);

      final parts = mainScriptRef.uri!.split('/')..removeLast();
      final libraries = isolate.libraries!;

      if (parts.isEmpty) {
        for (final lib in libraries) {
          if (lib.uri == mainScriptRef.uri) {
            return await pushObject(lib, scriptRef: mainScriptRef);
          }
        }
      }
      await pushObject(mainScriptRef, scriptRef: mainScriptRef);
    }
  }

  Future<void> findAndSelectNodeForObject(ObjRef obj) async {
    codeViewController.clearState();
    ScriptRef? script;
    try {
      final node = await programExplorerController.searchFileExplorer(obj);
      script = node.script ?? node.location!.scriptRef;
    } on StateError {
      // The node doesn't exist, so it must be an instance or an object from
      // the object store.
      programExplorerController.clearSelection();
    }
    await pushObject(obj, scriptRef: script);
  }
}
