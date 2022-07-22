// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose.dart';
import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import 'program_explorer_model.dart';

class ProgramExplorerController extends DisposableController
    with AutoDisposeControllerMixin {
  /// The outline view nodes for the currently selected library.
  ValueListenable<List<VMServiceObjectNode>> get outlineNodes => _outlineNodes;
  final _outlineNodes = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<bool> get isLoadingOutline => _isLoadingOutline;
  final _isLoadingOutline = ValueNotifier<bool>(false);

  /// The currently selected node in the Program Explorer file picker.
  VMServiceObjectNode? _scriptSelection;

  /// The currently selected node in the Program Explorer outline.
  ValueListenable<VMServiceObjectNode?> get outlineSelection =>
      _outlineSelection;
  final _outlineSelection = ValueNotifier<VMServiceObjectNode?>(null);

  /// The processed roots of the tree.
  ValueListenable<List<VMServiceObjectNode>> get rootObjectNodes =>
      _rootObjectNodes;
  final _rootObjectNodes = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<int> get selectedNodeIndex => _selectedNodeIndex;
  final _selectedNodeIndex = ValueNotifier<int>(0);

  IsolateRef? _isolate;

  /// Notifies that the controller has finished initializing.
  ValueListenable<bool> get initialized => _initialized;
  final _initialized = ValueNotifier<bool>(false);
  bool _initializing = false;

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
            .isolateDebuggerState(_isolate)!
            .isolateNow!
            .libraries!
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
      scriptManager.sortedScripts,
      refresh,
    );
  }

  Future<void> selectScriptNode(ScriptRef? script) async {
    if (!initialized.value) {
      return;
    }
    await _selectScriptNode(script, _rootObjectNodes.value);
    _rootObjectNodes.notifyListeners();
  }

  Future<void> _selectScriptNode(
    ScriptRef? script,
    List<VMServiceObjectNode> nodes,
  ) async {
    final searchCondition = (node) => node.script?.uri == script!.uri;
    for (final node in nodes) {
      final result = node.firstChildWithCondition(searchCondition);
      if (result != null) {
        await selectNode(result);
        result.expandAscending();
        _selectedNodeIndex.value = _calculateNodeIndex(
          matchingNodeCondition: searchCondition,
          includeCollapsedNodes: false,
        );
        return;
      }
    }
  }

  int _calculateNodeIndex({
    bool matchingNodeCondition(VMServiceObjectNode node)?,
    bool includeCollapsedNodes = true,
  }) {
    // Index tracks the position of the node in the flat-list representation of
    // the tree:
    var index = 0;
    for (final node in _rootObjectNodes.value) {
      final matchingNode = depthFirstTraversal(
        node,
        returnCondition: matchingNodeCondition,
        exploreChildrenCondition: includeCollapsedNodes
            ? null
            : (VMServiceObjectNode node) => node.isExpanded,
        action: (VMServiceObjectNode _) => index++,
      );
      if (matchingNode != null) return index;
    }
    // If the node wasn't found, return -1.
    return -1;
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
  Future<void> selectNode(VMServiceObjectNode node) async {
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
      final newOutlineNodes = await _scriptSelection!.outline;
      if (newOutlineNodes != null) {
        _outlineNodes.replaceAll(newOutlineNodes);
      }
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

  /// Sets the current [_outlineSelection] value to null, and resets the
  /// [_outlineNodes] tree for the current [_scriptSelection] by
  /// collapsing and unselecting all nodes.
  void resetOutline() {
    _outlineSelection.value = null;

    for (final node in _outlineNodes.value) {
      breadthFirstTraversal<VMServiceObjectNode>(
        node,
        action: (VMServiceObjectNode node) {
          node
            ..collapse()
            ..unselect();
        },
      );
    }

    _outlineNodes.notifyListeners();
  }

  void expandToNode(VMServiceObjectNode node) {
    node.expandAscending();
    _outlineNodes.notifyListeners();
  }

  /// Updates `node` with a fully populated VM service [Obj].
  ///
  /// If `node.object` is already an instance of [Obj], this function
  /// immediately returns.
  Future<void> populateNode(VMServiceObjectNode node) async {
    final object = node.object;
    final service = serviceManager.service;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id;

    Future<List<Obj>> getObjects(Iterable<ObjRef> objs) {
      return Future.wait(
        objs.map(
          (o) => service!.getObject(isolateId!, o.id!),
        ),
      );
    }

    Future<List<Func>> getFuncs(
      Iterable<FuncRef> funcs,
      Iterable<FieldRef>? fields,
    ) async {
      final res = await getObjects(
        funcs.where(
          (f) => !_isSyntheticAccessor(f, fields as List<FieldRef>),
        ),
      );
      return res.cast<Func>();
    }

    if (object == null || object is Obj) {
      return;
    } else if (object is LibraryRef) {
      final lib = await service!.getObject(isolateId!, object.id!) as Library;
      final results = await Future.wait([
        getObjects(lib.variables!),
        getFuncs(lib.functions!, lib.variables),
      ]);
      lib.variables = results[0].cast<Field>();
      lib.functions = results[1].cast<Func>();
      node.updateObject(lib);
    } else if (object is ClassRef) {
      final clazz = await service!.getObject(isolateId!, object.id!) as Class;
      final results = await Future.wait([
        getObjects(clazz.fields!),
        getFuncs(clazz.functions!, clazz.fields),
      ]);
      clazz.fields = results[0].cast<Field>();
      clazz.functions = results[1].cast<Func>();
      node.updateObject(clazz);
    } else {
      final obj = await service!.getObject(isolateId!, object.id!);
      node.updateObject(obj);
    }
  }
}
