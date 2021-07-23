import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../version.dart';
import 'object_tree_selector.dart';

class VMServiceLibraryContents {
  const VMServiceLibraryContents({
    this.lib,
    this.classes,
    this.functions,
    this.fields,
  });

  final Library lib;
  final List<ClassRef> classes;
  final List<FuncRef> functions;
  final List<FieldRef> fields;

  static Future<VMServiceLibraryContents> getLibraryContents(
      LibraryRef libRef) async {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
    final service = serviceManager.service;

    final lib = await service.getObject(isolateId, libRef.id) as Library;
    var classes = <ClassRef>[];
    var functions = <FuncRef>[];
    var fields = <FieldRef>[];

    if (!displayLibraryExplorer) {
      classes.addAll(lib.classes);
      functions.addAll(lib.functions);
      fields.addAll(lib.variables);

      // Before 3.46, ClassRef, FuncRef, and FieldRef didn't contain location
      // information and couldn't be mapped to their parent scripts. For older
      // versions of the protocol, we need to request the full objects for
      // everything. We'll avoid doing this for versions >= 3.46 and lazily
      // populate the tree with full instances as the user navigates.
      if (!await service.isProtocolVersionSupported(
        supportedVersion: SemanticVersion(major: 3, minor: 46),
      )) {
        final classesRequests = lib.classes.map(
          (clazz) async =>
              await service.getObject(isolateId, clazz.id) as Class,
        );

        classes = await Future.wait(classesRequests);
      }

      final funcsRequests = lib.functions.map(
        (func) async => await service.getObject(isolateId, func.id) as Func,
      );
      functions = await Future.wait(funcsRequests);

      final fieldsRequests = lib.variables.map(
        (field) async => await service.getObject(isolateId, field.id) as Field,
      );
      fields = await Future.wait(fieldsRequests);
    }

    // Remove scripts pulled into libraries via mixins.
    lib.scripts.removeWhere((e) => !e.uri.contains(lib.uri));

    return VMServiceLibraryContents(
      lib: lib,
      classes: classes,
      functions: functions,
      fields: fields,
    );
  }
}

class ObjectTreeController {
  final programStructure = <VMServiceLibraryContents>[];

  ValueListenable<int> get objectCount => _objectCount;
  final _objectCount = ValueNotifier<int>(0);

  ValueListenable<VMServiceObjectNode> get selected => _selected;
  final _selected = ValueNotifier<VMServiceObjectNode>(null);

  // Cache of object IDs to their containing library to allow for easier
  // refreshing of library content, particularly for scripts.
  final _objectIdToLibrary = <String, LibraryRef>{};

  IsolateRef _isolate;

  Future<void> get initialized => _completer.future;

  bool _initializing = false;
  var _completer = Completer<void>();

  static bool _isSyntheticAccessor(FuncRef function, List<FieldRef> fields) {
    if (serviceManager.service.isProtocolVersionSupportedNow(
      supportedVersion: SemanticVersion(major: 3, minor: 47),
    )) {
      // TODO(bkonyi)
      /*if (function.synthetic) {
        return true;
      }*/
    }
    for (final field in fields) {
      if (function.name == field.name || function.name == '${field.name}=') {
        return true;
      }
    }
    return false;
  }

  /// Initializes the program structure.
  Future<void> initialize() {
    if (!_initializing) {
      _initializing = true;
      Future.wait(
        serviceManager
            .isolateManager.mainIsolateDebuggerState.isolateNow.libraries
            .map(
          (lib) => VMServiceLibraryContents.getLibraryContents(lib),
        ),
      ).then((libraries) {
        _isolate = serviceManager.isolateManager.selectedIsolate.value;

        int count = 0;
        int libs = 0;
        int classes = 0;
        int fields = 0;
        int scripts = 0;
        int functions = 0;

        void mapIdsToLibrary(LibraryRef lib, Iterable<ObjRef> objs) {
          for (final e in objs) {
            _objectIdToLibrary[e.id] = lib;
            count++;
          }
        }

        for (final libContents in libraries) {
          final lib = libContents.lib;
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

          libs++;
          classes += libContents.classes.length;
          fields += libContents.fields.length;
          functions += libContents.functions.length;
          scripts += lib.scripts.length;
        }

        _objectCount.value += count;
        final total = libs + classes + fields + scripts + functions;
        print(
            'libs: $libs classes: $classes fields: $fields scripts: $scripts functions: $functions total: $total');
        programStructure.addAll(libraries.cast<VMServiceLibraryContents>());
        _completer.complete();
      });
    }
    return _completer.future;
  }

  Future<void> refresh() {
    _completer = Completer<void>();
    _objectIdToLibrary.clear();
    _selected.value = null;
    programStructure.clear();
    return initialize();
  }

  void selectNode(VMServiceObjectNode node) {
    if (!node.isSelectable) {
      return;
    }
    if (_selected.value != node) {
      node.isSelected = true;
      _selected.value?.isSelected = false;
      _selected.value = node;
    }
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

    final library = programStructure.firstWhere(
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
  }
}
