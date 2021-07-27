// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../globals.dart';
import '../trees.dart';
import '../utils.dart';
import 'program_explorer_model.dart';

class ProgramExplorerController extends DisposableController
    with AutoDisposeControllerMixin {
  ProgramExplorerController() {
    addAutoDisposeListener(
      serviceManager.isolateManager.selectedIsolate,
      () => refresh(),
    );
  }

  /// A list of objects containing the contents of each library.
  final _programStructure = <VMServiceLibraryContents>[];

  /// The total number of selectable objects in the unfiltered tree.
  ValueListenable<int> get objectCount => _objectCount;
  final _objectCount = ValueNotifier<int>(0);

  /// The total number of selectable objects in the filtered tree.
  ValueListenable<int> get filteredObjectCount => _filteredObjectCount;
  final _filteredObjectCount = ValueNotifier<int>(0);

  /// The currently selected node.
  VMServiceObjectNode _selected;

  /// The processed roots of the tree.
  ValueListenable<List<VMServiceObjectNode>> get rootObjectNodes =>
      _rootObjectNodes;
  final _rootObjectNodes = ValueNotifier<List<VMServiceObjectNode>>([]);

  /// Cache of object IDs to their containing library to allow for easier
  /// refreshing of library content, particularly for scripts.
  final _objectIdToLibrary = <String, LibraryRef>{};

  IsolateRef _isolate;

  /// Notifies that the controller has finished initializing.
  ValueListenable<bool> get initialized => _initializationListenable;
  final _initializationListenable = ValueNotifier<bool>(false);
  bool _initializing = false;

  /// Attaches filtering information to package:vm_service objects.
  final _shouldFilterExpando = Expando<bool>('shouldFilter');

  /// The current list of library contents that match the current filter. This
  /// is a strict subset of contents stored in [_programStructure].
  List<VMServiceLibraryContents> _filteredItems;

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
      final filteredFunctions = libContents.functions.where(
        (e) => !_isSyntheticAccessor(e, libContents.fields),
      );
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
    updateVisibleNodes();

    // Initial tree contains all nodes, so we can use the filtered object count
    // based on the actual tree structure instead of trying to count here using
    // logic not based on the tree structure itself.
    _objectCount.value = _filteredObjectCount.value;
    _initializationListenable.value = true;
  }

  /// Clears controller state and re-initializes.
  Future<void> refresh() async {
    _objectIdToLibrary.clear();
    _selected = null;
    _initializationListenable.value = false;
    _initializing = false;
    _programStructure.clear();
    _objectCount.value = 0;
    _filteredObjectCount.value = 0;
    return await initialize();
  }

  /// Marks [node] as the currently selected node, clearing the selection state
  /// of any currently selected node.
  void selectNode(VMServiceObjectNode node) {
    if (!node.isSelectable) {
      return;
    }
    if (_selected != node) {
      node.isSelected = true;
      _selected?.isSelected = false;
      _selected = node;
    }
  }

  /// Rebuilds the tree nodes, only creating nodes for objects that match
  /// [filterText].
  void updateVisibleNodes([String filterText = '']) {
    for (final ref in _programStructure) {
      bool includeLib = false;
      if (ref.lib.uri.caseInsensitiveFuzzyMatch(filterText)) {
        includeLib = true;
      }

      for (final script in ref.lib.scripts) {
        _shouldFilterExpando[script] = false;
        if (script.uri.caseInsensitiveFuzzyMatch(filterText)) {
          _shouldFilterExpando[script] = true;
        }
      }

      for (final clazz in ref.classes) {
        _shouldFilterExpando[clazz] = false;
        if (clazz.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[clazz] = true;
        }
      }

      for (final function in ref.functions) {
        _shouldFilterExpando[function] = false;
        if (function.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[function] = true;
        }
      }

      for (final field in ref.fields) {
        _shouldFilterExpando[field] = false;
        if (field.name.caseInsensitiveFuzzyMatch(filterText)) {
          includeLib = true;
          _shouldFilterExpando[field] = true;
        }
      }
      _shouldFilterExpando[ref.lib] = includeLib;
    }
    _filteredItems = _programStructure
        .where((ref) => _shouldFilterExpando[ref.lib])
        .toList();

    // Remove the cached value here; it'll be re-computed the next time we need
    // it.
    _rootObjectNodes.value = VMServiceObjectNode.createRootsFrom(
      _filteredItems,
      _shouldFilterExpando,
    );
    _updateFilteredObjectCount();
  }

  /// Updates `node` with a fully populated VM service [Obj].
  ///
  /// If `node.object` is already an instance of [Obj], this function
  /// immediately returns.
  Future<void> populateNode(VMServiceObjectNode node) async {
    if (node.object == null) {
      return;
    }
    final id = node.object.id;
    final object = node.object;
    if (object is Obj) {
      return;
    }
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
      int count = 0;
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
      clazz.fields.clear();
      clazz.fields.addAll(fields.cast<FieldRef>());
      count += clazz.fields.length;

      final functions = await Future.wait(
        clazz.functions.map(
          (e) => service.getObject(_isolate.id, e.id).then((e) => e as Func),
        ),
      );
      clazz.functions.clear();
      clazz.functions.addAll(
        functions
            .where((e) => !_isSyntheticAccessor(e, clazz.fields))
            .cast<FuncRef>(),
      );
      count += clazz.functions.length;
      _objectCount.value += count;
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

    // We might have expanded a Class and added new entries to the tree. Make
    // sure we account for these new nodes to the filtered object count.
    _updateFilteredObjectCount();
  }

  /// Iterates over the tree and counts the number of selectable nodes.
  void _updateFilteredObjectCount() {
    _filteredObjectCount.value = rootObjectNodes.value.fold(0, (prev, e) {
      int count = 0;
      breadthFirstTraversal<VMServiceObjectNode>(e, action: (e) {
        if (e.isSelectable) {
          count++;
        }
      });
      return prev + count;
    });
  }
}
