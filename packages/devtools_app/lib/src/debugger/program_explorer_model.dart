// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../trees.dart';
import '../version.dart';


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
        (clazz) async => await service.getObject(isolateId, clazz.id) as Class,
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

/// A node in a tree of VM service objects.
///
/// A node can represent one of the following:
///   - Directory
///   - Library (with or without a script)
///   - Script
///   - Class
///   - Field
///   - Function
class VMServiceObjectNode extends TreeNode<VMServiceObjectNode> {
  VMServiceObjectNode(
    this.name,
    this.object, {
    this.isSelectable = true,
  });

  final String name;
  bool isSelectable;

  ObjRef object;
  ScriptRef script;

  @override
  bool isSelected = false;

  /// This exists to allow for O(1) lookup of children when building the tree.
  final Map<String, VMServiceObjectNode> _childrenAsMap = {};

  @override
  bool get isExpandable => super.isExpandable || object is ClassRef;

  /// Given a flat list of service protocol scripts, return a tree of scripts
  /// representing the best hierarchical grouping.
  static List<VMServiceObjectNode> createRootsFrom(
    List<VMServiceLibraryContents> libs,
    Expando<bool> shouldFilterExpando,
  ) {
    // The name of this node is not exposed to users.
    final root = VMServiceObjectNode('<root>', ObjRef(id: '0'));

    for (var lib in libs) {
      if (!shouldFilterExpando[lib.lib]) {
        continue;
      }
      for (final script in lib.lib.scripts) {
        if (!shouldFilterExpando[script]) {
          continue;
        }
        _buildScriptNode(root, script, lib: lib.lib);
      }

      for (final clazz in lib.classes) {
        if (!shouldFilterExpando[clazz]) {
          continue;
        }
        final clazzNode = _buildScriptNode(root, clazz.location.script)
            ._getCreateChild(clazz.name, clazz);
        if (clazz is Class) {
          for (final function in clazz.functions) {
            clazzNode._getCreateChild(function.name, function);
          }
          for (final field in clazz.fields) {
            clazzNode._getCreateChild(field.name, field);
          }
        }
      }

      for (final function in lib.functions) {
        if (!shouldFilterExpando[function]) {
          continue;
        }
        _buildScriptNode(root, function.location.script)
            ._getCreateChild(function.name, function);
      }

      for (final field in lib.fields) {
        if (!shouldFilterExpando[field]) {
          continue;
        }
        _buildScriptNode(root, field.location.script)
            ._getCreateChild(field.name, field);
      }
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    // Sort each subtree to use the following ordering:
    //   - Scripts
    //   - Classes
    //   - Functions
    //   - Variables
    for (final child in root.children) {
      child._sortEntriesByType();
    }
    root.children.sort((a, b) => a.name.compareTo(b.name));

    return root.children;
  }

  static VMServiceObjectNode _buildScriptNode(
    VMServiceObjectNode node,
    ScriptRef script, {
    LibraryRef lib,
  }) {
    final parts = script.uri.split('/');
    final name = parts.removeLast();
    final dir = parts.join('/');

    if (parts.isNotEmpty) {
      // Root nodes shouldn't be selectable unless they're a library node.
      node = node._getCreateChild(dir, null, isSelectable: false);
    }
    node = node._getCreateChild(name, script);
    if (!node.isSelectable) {
      node.isSelectable = true;
    }
    node.script = script;

    // Is this is a top-level node and a library is specified, this must be a
    // library node.
    if (parts.isEmpty && lib != null) {
      node.object = lib;
    }
    return node;
  }

  VMServiceObjectNode _getCreateChild(
    String name,
    ObjRef object, {
    bool isSelectable = true,
  }) {
    return _childrenAsMap.putIfAbsent(
      name,
      () => _createChild(name, object, isSelectable: isSelectable),
    );
  }

  VMServiceObjectNode _createChild(
    String name,
    ObjRef object, {
    bool isSelectable = true,
  }) {
    final child = VMServiceObjectNode(
      name,
      object,
      isSelectable: isSelectable,
    );
    child.parent = this;
    children.add(child);
    return child;
  }

  void updateObject(Obj object) {
    if (this.object is! Class && object is Class) {
      for (final function in object.functions) {
        _createChild(function.name, function);
      }
      for (final field in object.fields) {
        _createChild(field.name, field);
      }
      _sortEntriesByType();
    }
    this.object = object;
  }

  /// Clear the _childrenAsMap map recursively to save memory.
  void _trimChildrenAsMapEntries() {
    _childrenAsMap.clear();

    for (var child in children) {
      child._trimChildrenAsMapEntries();
    }
  }

  void _sortEntriesByType() {
    final scriptNodes = <VMServiceObjectNode>[];
    final classNodes = <VMServiceObjectNode>[];
    final functionNodes = <VMServiceObjectNode>[];
    final variableNodes = <VMServiceObjectNode>[];

    for (final child in children) {
      switch (child.object.runtimeType) {
        case ScriptRef:
        case Script:
        case LibraryRef:
        case Library:
          scriptNodes.add(child);
          break;
        case ClassRef:
        case Class:
          classNodes.add(child);
          break;
        case FuncRef:
        case Func:
          functionNodes.add(child);
          break;
        case FieldRef:
        case Field:
          variableNodes.add(child);
          break;
        default:
          throw StateError('Unexpected type: ${child.object.runtimeType}');
      }
      child._sortEntriesByType();
    }

    scriptNodes.sort((a, b) {
      // Inputs can be either scripts or libraries, both of which always have
      // uris, so we'll just case as dynamic.
      final scriptA = a.object as dynamic;
      final scriptB = b.object as dynamic;
      return scriptA.uri.compareTo(scriptB.uri);
    });

    classNodes.sort((a, b) {
      final objA = a.object as ClassRef;
      final objB = b.object as ClassRef;
      return objA.name.compareTo(objB.name);
    });

    functionNodes.sort((a, b) {
      final objA = a.object as FuncRef;
      final objB = b.object as FuncRef;
      return objA.name.compareTo(objB.name);
    });

    variableNodes.sort((a, b) {
      final objA = a.object as FieldRef;
      final objB = b.object as FieldRef;
      return objA.name.compareTo(objB.name);
    });

    children.clear();
    children.addAll([
      ...scriptNodes,
      ...classNodes,
      ...functionNodes,
      ...variableNodes,
    ]);
  }

  @override
  int get hashCode => script?.uri.hashCode ?? object?.hashCode ?? name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! VMServiceObjectNode) return false;
    final VMServiceObjectNode node = other;

    return node.name == name &&
        node.object == object &&
        node.script?.uri == script?.uri;
  }

  @override
  TreeNode<VMServiceObjectNode> shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
