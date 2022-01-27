// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/auto_dispose.dart';
import '../shared/globals.dart';
import '../shared/utils.dart';
import 'debugger_controller.dart';
import 'program_explorer_model.dart';

class ProgramExplorerController extends DisposableController
    with AutoDisposeControllerMixin {
  ProgramExplorerController({@required this.debuggerController});

  /// The outline view nodes for the currently selected library.
  ValueListenable<List<VMServiceObjectNode>> get outlineNodes => _outlineNodes;
  final _outlineNodes = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<bool> get isLoadingOutline => _isLoadingOutline;
  final _isLoadingOutline = ValueNotifier<bool>(false);

  /// The currently selected node in the Program Explorer file picker.
  VMServiceObjectNode _scriptSelection;

  /// The currently selected node in the Program Explorer outline.
  ValueListenable<VMServiceObjectNode> get outlineSelection =>
      _outlineSelection;
  final _outlineSelection = ValueNotifier<VMServiceObjectNode>(null);

  /// The processed roots of the tree.
  ValueListenable<List<VMServiceObjectNode>> get rootObjectNodes =>
      _rootObjectNodes;
  final _rootObjectNodes = ListValueNotifier<VMServiceObjectNode>([]);

  IsolateRef _isolate;

  /// Notifies that the controller has finished initializing.
  ValueListenable<bool> get initialized => _initialized;
  final _initialized = ValueNotifier<bool>(false);
  bool _initializing = false;

  DebuggerController debuggerController;

  /// Returns true if [function] is a getter or setter that was not explicitly
  /// defined (e.g., `int foo` creates `int get foo` and `set foo(int)`).
  static bool _isSyntheticAccessor(FuncRef function, List<FieldRef> fields) {
    for (final field in fields) {
      if (function.name == field.name || function.name == '${field.name}=') {
        return true;
      }
    }
    return false;
  }

  /// Initializes the program structure.
  void initialize() {
    if (_initializing) {
      return;
    }
    _initializing = true;

    _isolate = serviceManager.isolateManager.selectedIsolate.value;
    final libraries = _isolate != null
        ? serviceManager.isolateManager
            .isolateDebuggerState(_isolate)
            .isolateNow
            .libraries
        : <LibraryRef>[];

    // Build the initial tree.
    final nodes = VMServiceObjectNode.createRootsFrom(
      this,
      libraries,
    );
    _rootObjectNodes.replaceAll(nodes);
    _initialized.value = true;
  }

  void initListeners() {
    // Re-initialize after reload.
    // TODO(elliette): If file was opened from before the reload, we should try
    // to open that one instead of the entrypoint file.
    addAutoDisposeListener(
      debuggerController.sortedScripts,
      refresh,
    );
  }

  void selectScriptNode(ScriptRef script) {
    if (!initialized.value) {
      return;
    }
    _selectScriptNode(script, _rootObjectNodes.value);
    _rootObjectNodes.notifyListeners();
  }

  void _selectScriptNode(
    ScriptRef script,
    List<VMServiceObjectNode> nodes,
  ) {
    for (final node in nodes) {
      final result = node.firstChildWithCondition(
        (node) => node.script?.uri == script.uri,
      );
      if (result != null) {
        selectNode(result);
        result.expandAscending();
        return;
      }
    }
  }

  /// Clears controller state and re-initializes.
  void refresh() {
    _scriptSelection = null;
    _outlineSelection.value = null;
    _isLoadingOutline.value = true;
    _outlineNodes.clear();
    _initialized.value = false;
    _initializing = false;
    return initialize();
  }

  /// Marks [node] as the currently selected node, clearing the selection state
  /// of any currently selected node.
  /// TODO(elliette): Scroll to node in program explorer tree when selected.
  void selectNode(VMServiceObjectNode node) async {
    if (!node.isSelectable) {
      return;
    }
    if (_scriptSelection != node) {
      await populateNode(node);
      node.select();
      _scriptSelection?.unselect();
      _scriptSelection = node;
      _isLoadingOutline.value = true;
      _outlineSelection.value = null;
      _outlineNodes.replaceAll(await _scriptSelection.outline);
      _isLoadingOutline.value = false;
    }
  }

  void selectOutlineNode(VMServiceObjectNode node) {
    if (!node.isSelectable) {
      return;
    }
    if (_outlineSelection.value != node) {
      node.select();
      _outlineSelection.value?.unselect();
      _outlineSelection.value = node;
    }
  }

  /// Updates `node` with a fully populated VM service [Obj].
  ///
  /// If `node.object` is already an instance of [Obj], this function
  /// immediately returns.
  Future<void> populateNode(VMServiceObjectNode node) async {
    final object = node.object;
    final service = serviceManager.service;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;

    Future<List<Obj>> getObjects(Iterable<ObjRef> objs) {
      return Future.wait(
        objs.map(
          (o) => service.getObject(isolateId, o.id),
        ),
      );
    }

    Future<List<Func>> getFuncs(
      Iterable<FuncRef> funcs,
      Iterable<FieldRef> fields,
    ) async {
      final res = await getObjects(
        funcs.where(
          (f) => !_isSyntheticAccessor(f, fields),
        ),
      );
      return res.cast<Func>();
    }

    if (object == null || object is Obj) {
      return;
    } else if (object is LibraryRef) {
      final lib = await service.getObject(isolateId, object.id) as Library;
      final results = await Future.wait([
        getObjects(lib.variables),
        getFuncs(lib.functions, lib.variables),
      ]);
      lib.variables = results[0].cast<Field>();
      lib.functions = results[1].cast<Func>();
      node.updateObject(lib);
    } else if (object is ClassRef) {
      final clazz = await service.getObject(isolateId, object.id) as Class;
      final results = await Future.wait([
        getObjects(clazz.fields),
        getFuncs(clazz.functions, clazz.fields),
      ]);
      clazz.fields = results[0].cast<Field>();
      clazz.functions = results[1].cast<Func>();
      node.updateObject(clazz);
    } else {
      final obj = await service.getObject(isolateId, object.id);
      node.updateObject(obj);
    }
  }
}
