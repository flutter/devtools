// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../utils.dart';
import 'program_explorer_model.dart';

class ProgramExplorerController extends DisposableController
    with AutoDisposeControllerMixin {
  ProgramExplorerController() {
    addAutoDisposeListener(
      serviceManager.isolateManager.selectedIsolate,
      refresh,
    );
  }

  /// A list of objects containing the contents of each library.
  final _programStructure = <VMServiceLibraryContents>[];

  /// The outline view nodes for the currently selected library.
  ValueListenable<List<VMServiceObjectNode>> get outlineNodes => _outlineNodes;
  final _outlineNodes = ListValueNotifier<VMServiceObjectNode>([]);

  ValueListenable<bool> get isLoadingOutline => _isLoadingOutline;
  final _isLoadingOutline = ValueNotifier<bool>(false);

  /// The currently selected node.
  VMServiceObjectNode _selected;

  /// The processed roots of the tree.
  ValueListenable<List<VMServiceObjectNode>> get rootObjectNodes =>
      _rootObjectNodes;
  final _rootObjectNodes = ListValueNotifier<VMServiceObjectNode>([]);

  /// Cache of object IDs to their containing library to allow for easier
  /// refreshing of library content, particularly for scripts.
  final _objectIdToLibrary = <String, LibraryRef>{};

  IsolateRef _isolate;

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
  // TODO(bkonyi): reinitialize after hot reload.
  Future<void> initialize() async {
    if (_initializing) {
      return;
    }
    _initializing = true;
    _isolate = serviceManager.isolateManager.selectedIsolate.value;
    final libraries = await Future.wait(
      serviceManager.isolateManager
          .isolateDebuggerState(_isolate)
          .isolateNow
          .libraries
          .map(
            (lib) => VMServiceLibraryContents.getLibraryContents(lib),
          ),
    );

    void mapIdsToLibrary(LibraryRef lib, Iterable<ObjRef> objs) {
      for (final e in objs) {
        _objectIdToLibrary[e.id] = lib;
      }
    }

    for (final libContents in libraries) {
      final lib = libContents.lib;
      mapIdsToLibrary(lib, [lib]);
      mapIdsToLibrary(lib, lib.scripts);
      mapIdsToLibrary(lib, libContents.classes);
      mapIdsToLibrary(lib, libContents.fields);

      // Filter out synthetic getters/setters
      final filteredFunctions = libContents.functions
          .where(
            (e) => !_isSyntheticAccessor(e, libContents.fields),
          )
          .toList();
      libContents.functions.clear();
      libContents.functions.addAll(filteredFunctions);
      mapIdsToLibrary(lib, libContents.functions);

      // Account for entries in library parts.
      mapIdsToLibrary(lib, libContents.functions.map((e) => e.location.script));
      mapIdsToLibrary(lib, libContents.classes.map((e) => e.location.script));
      mapIdsToLibrary(lib, libContents.fields.map((e) => e.location.script));
    }

    _programStructure.addAll(libraries);

    // Build the initial tree.
    final nodes = VMServiceObjectNode.createRootsFrom(
      this,
      _programStructure,
    );
    _rootObjectNodes.addAll(nodes);
    _initialized.value = true;
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
  Future<void> refresh() async {
    _objectIdToLibrary.clear();
    _selected = null;
    _isLoadingOutline.value = true;
    _outlineNodes.clear();
    _initialized.value = false;
    _initializing = false;
    _programStructure.clear();
    return await initialize();
  }

  /// Marks [node] as the currently selected node, clearing the selection state
  /// of any currently selected node.
  void selectNode(VMServiceObjectNode node) async {
    if (!node.isSelectable) {
      return;
    }
    if (_selected != node) {
      node.select();
      _selected?.unselect();
      _selected = node;
      _isLoadingOutline.value = true;
      _outlineNodes
        ..clear()
        ..addAll(await _selected.outline);
      _isLoadingOutline.value = false;
    }
  }

  /// Updates `node` with a fully populated VM service [Obj].
  ///
  /// If `node.object` is already an instance of [Obj], this function
  /// immediately returns.
  Future<void> populateNode(VMServiceObjectNode node) async {
    final object = node.object;
    if (object == null || object is Obj) {
      return;
    }
    final id = node.object.id;
    final service = serviceManager.service;

    // We don't know if the object ID is still valid. Re-request the library
    // and find the object again.
    final lib = _objectIdToLibrary[id];

    final refreshedLib =
        await service.getObject(_isolate.id, lib.id) as Library;
    dynamic updatedObj;

    // Find the relevant object reference in the refreshed library.
    if (object is ClassRef) {
      updatedObj = refreshedLib.classes.firstWhere(
        (k) => k.name == object.name,
      );
    } else if (object is FieldRef) {
      updatedObj = refreshedLib.variables.firstWhere(
        (v) => v.name == object.name,
      );
    } else if (object is FuncRef) {
      updatedObj = refreshedLib.functions.firstWhere(
        (f) => f.name == object.name,
      );
    } else if (object is ScriptRef) {
      updatedObj = refreshedLib.scripts.firstWhere(
        (s) => s.uri == object.uri,
      );
    } else {
      throw StateError('Unexpected type: ${object.runtimeType}');
    }

    // Request the full object for the node we're interested in and update all
    // instances of the original reference object in the program structure with
    // the full object.
    updatedObj = await service.getObject(_isolate.id, updatedObj.id);

    final library = _programStructure.firstWhere(
      (e) => e.lib.uri == lib.uri,
    );
    if (updatedObj is Class) {
      final clazz = updatedObj;
      final i = library.classes.indexWhere(
        (c) => c.name == clazz.name,
      );
      library.classes[i] = clazz;
      final fields = await Future.wait(
        clazz.fields.map(
          (e) => service.getObject(_isolate.id, e.id),
        ),
      );
      clazz.fields
        ..clear()
        ..addAll(fields.cast<FieldRef>());

      final functions = await Future.wait(
        clazz.functions.map(
          (e) => service.getObject(_isolate.id, e.id).then((e) => e as Func),
        ),
      );
      clazz.functions
        ..clear()
        ..addAll(
          functions
              .where((e) => !_isSyntheticAccessor(e, clazz.fields))
              .cast<FuncRef>(),
        );
    } else if (updatedObj is Field) {
      final i = library.fields.indexWhere(
        (f) => f.name == updatedObj.name,
      );
      library.fields[i] = updatedObj;
    } else if (object is Func) {
      final i = library.functions.indexWhere(
        (f) => f.name == updatedObj.name,
      );
      library.functions[i] = updatedObj;
    }

    _objectIdToLibrary.remove(id);
    _objectIdToLibrary[updatedObj.id] = library.lib;

    // Sets the contents of the node to contain the full object.
    node.updateObject(updatedObj);
  }
}
