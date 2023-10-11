// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/trees.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'program_explorer_model.dart';

class ProgramExplorerController extends DisposableController
    with AutoDisposeControllerMixin {
  /// [showCodeNodes] controls whether or not [Code] nodes are displayed in the
  /// outline view.
  ProgramExplorerController({
    this.showCodeNodes = false,
  });

  /// The outline view nodes for the currently selected library.
  ValueListenable<List<VMServiceObjectNode>> get outlineNodes => _outlineNodes;
  final _outlineNodes = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<bool> get isLoadingOutline => _isLoadingOutline;
  final _isLoadingOutline = ValueNotifier<bool>(false);

  /// The currently selected node in the Program Explorer file picker.
  @visibleForTesting
  VMServiceObjectNode? get scriptSelection => _scriptSelection;
  VMServiceObjectNode? _scriptSelection;

  /// The processed roots of the tree.
  ValueListenable<List<VMServiceObjectNode>> get rootObjectNodes =>
      rootObjectNodesInternal;
  @visibleForTesting
  final rootObjectNodesInternal = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<int> get selectedNodeIndex => _selectedNodeIndex;
  final _selectedNodeIndex = ValueNotifier<int>(0);

  /// The currently selected node in the Program Explorer outline.
  VMServiceObjectNode? _outlineSelection;

  /// Notifies that the controller has finished initializing.
  ValueListenable<bool> get initialized => _initialized;
  final _initialized = ValueNotifier<bool>(false);
  bool _initializing = false;

  /// Controls whether or not [Code] nodes are displayed in the outline view.
  final bool showCodeNodes;

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
  Future<void> initialize() async {
    if (_initializing) {
      return;
    }
    _initializing = true;

    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    final libraries = isolate != null
        ? serviceConnection.serviceManager.isolateManager
            .isolateState(isolate)
            .isolateNow!
            .libraries!
        : <LibraryRef>[];

    if (scriptManager.sortedScripts.value.isEmpty && isolate != null) {
      await scriptManager.retrieveAndSortScripts(isolate);
    }

    // Build the initial tree.
    final nodes = VMServiceObjectNode.createRootsFrom(
      this,
      libraries,
    );
    rootObjectNodesInternal.replaceAll(nodes);
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
    if (script == null) {
      clearSelection();
      return;
    }
    await _selectScriptNode(script, rootObjectNodesInternal.value);
    rootObjectNodesInternal.notifyListeners();
  }

  Future<void> _selectScriptNode(
    ScriptRef? script,
    List<VMServiceObjectNode> nodes,
  ) async {
    bool searchCondition(node) => node.script?.uri == script!.uri;
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

  VMServiceObjectNode? findOutlineNode(ObjRef object) {
    return breadthFirstSearchObject(object, _outlineNodes.value);
  }

  int _calculateNodeIndex({
    bool Function(VMServiceObjectNode node)? matchingNodeCondition,
    bool includeCollapsedNodes = true,
  }) {
    // Index tracks the position of the node in the flat-list representation of
    // the tree:
    var index = 0;
    for (final node in rootObjectNodesInternal.value) {
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
  Future<void> refresh() {
    _scriptSelection = null;
    _outlineSelection = null;
    _isLoadingOutline.value = true;
    _outlineNodes.clear();
    _initialized.value = false;
    _initializing = false;
    return initialize();
  }

  void clearSelection() {
    _scriptSelection?.unselect();
    _scriptSelection = null;
    _outlineNodes.clear();
    _outlineSelection = null;
    rootObjectNodesInternal.notifyListeners();
  }

  void clearOutlineSelection() {
    _outlineSelection?.unselect();
    _outlineSelection = null;
    _outlineNodes.notifyListeners();
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
      _outlineSelection = null;
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
    if (_outlineSelection != node) {
      node.select();
      _outlineSelection?.unselect();
      _outlineSelection = node;
      _outlineNodes.notifyListeners();
    }
  }

  /// Sets the current [_outlineSelection] value to null, and resets the
  /// [_outlineNodes] tree for the current [_scriptSelection] by
  /// collapsing and unselecting all nodes.
  void resetOutline() {
    _outlineSelection = null;

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
    final service = serviceConnection.serviceManager.service;
    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id;

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
      final res = await Future.wait<Func>(
        funcs
            .where((f) => !_isSyntheticAccessor(f, fields as List<FieldRef>))
            .map<Future<Func>>(
              (f) => service!.getObject(isolateId!, f.id!).then((f) async {
                final func = f as Func;
                final codeRef = func.code;

                // Populate the [Code] objects in each function if we want to
                // show code nodes in the outline.
                if (showCodeNodes && codeRef != null) {
                  final code =
                      await service.getObject(isolateId, codeRef.id!) as Code;
                  func.code = code;
                  Code unoptimizedCode = code;
                  // `func.code` could be unoptimized code, so don't bother
                  // fetching it again.
                  if (func.unoptimizedCode != null &&
                      func.unoptimizedCode?.id! != code.id!) {
                    unoptimizedCode = await service.getObject(
                      isolateId,
                      func.unoptimizedCode!.id!,
                    ) as Code;
                  }
                  func.unoptimizedCode = unoptimizedCode;
                }
                return func;
              }),
            ),
      );
      return res.cast<Func>();
    }

    try {
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
    } on RPCError {
      // Swallow RPC errors that can be caused by the service disappearing.
    }
  }

  /// Searches and returns the script or library node in the FileExplorer
  /// which is the source location of the target [object].
  Future<VMServiceObjectNode> searchFileExplorer(ObjRef object) async {
    final service = serviceConnection.serviceManager.service!;
    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;

    // If `object` is a library, it will always be a root node and is simple to
    // find.
    if (object is LibraryRef) {
      final result = _searchRootObjectNodes(object)!;
      await result.populateLocation();
      return result;
    }

    // Otherwise, we need to find the target script to determine the library
    // the target node is listed under.
    final ScriptRef? targetScript = switch (object) {
      ClassRef(:final location?) ||
      FieldRef(:final location?) ||
      FuncRef(:final location?) =>
        location.script,
      Code(:final function?) => function.location?.script,
      ScriptRef() => object,
      _ => null,
    };

    if (targetScript == null) {
      throw StateError('Could not find script');
    }

    final scriptObj =
        await service.getObject(isolateId, targetScript.id!) as Script;
    final LibraryRef targetLib = scriptObj.library!;

    // Search targetLib only on the root level nodes (this is the most common
    // scenario).
    var libNode = _searchRootObjectNodes(targetLib);

    // If we couldn't find the target library as a root node, it's possible we
    // have a library defined using the `library` keyword by the user, which
    // will likely be under a directory node.
    libNode ??= breadthFirstSearchObject(
      scriptObj,
      rootObjectNodes.value,
    );

    // If the object's owning script URI is the same as the target library URI,
    // return the library node as the match.
    if (targetLib.uri == targetScript.uri) {
      return libNode!;
    }

    // Find the script node nested under the library.
    final scriptNode = breadthFirstSearchObject(
      targetScript,
      rootObjectNodes.value,
    );
    if (scriptNode == null) {
      throw StateError('Could not find script node');
    }
    await scriptNode.populateLocation();
    return scriptNode;
  }

  VMServiceObjectNode? _searchRootObjectNodes(ObjRef obj) {
    for (final rootNode in rootObjectNodes.value) {
      if (rootNode.object?.id == obj.id) {
        return rootNode;
      }
    }
    return null;
  }

  /// Performs a breath first search on the list of roots and returns the
  /// first node whose object is the same as the target [obj].
  VMServiceObjectNode? breadthFirstSearchObject(
    ObjRef obj,
    List<VMServiceObjectNode> roots,
  ) {
    for (final root in roots) {
      final match = breadthFirstTraversal<VMServiceObjectNode>(
        root,
        returnCondition: (node) => node.object?.id == obj.id,
      );
      if (match != null) {
        return match;
      }
    }
    return null;
  }
}
