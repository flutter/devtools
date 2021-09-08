// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../trees.dart';
import '../version.dart';
import 'program_explorer_controller.dart';

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
    this.controller,
    this.name,
    this.object, {
    this.isSelectable = true,
  });

  final ProgramExplorerController controller;
  final String name;
  bool isSelectable;

  ObjRef object;
  ScriptRef script;

  @override
  bool isSelected = false;

  /// This exists to allow for O(1) lookup of children when building the tree.
  final _childrenAsMap = <String, VMServiceObjectNode>{};

  @override
  bool shouldShow() {
    // TODO: implement shouldShow
    return true;
  }

  // TODO(bkonyi): handle empty classes
  @override
  bool get isExpandable => super.isExpandable || object is ClassRef;

  List<VMServiceObjectNode> _outline;
  Future<List<VMServiceObjectNode>> get outline async {
    if (_outline != null) {
      return _outline;
    }
    final root = VMServiceObjectNode(
      controller,
      '<root>',
      ObjRef(id: '0'),
    );

    String uri;
    Library lib;
    if (object is Library) {
      lib = object as Library;
      uri = lib.uri;
    } else {
      // Try to find the library in the tree. If the current node isn't a
      // library node, it's likely one of its parents are.
      VMServiceObjectNode libNode = this;
      while (libNode != null && libNode.object is! Library) {
        libNode = libNode.parent;
      }

      // In the case of patch files, the parent nodes won't include a library.
      // We'll need to search for the library URI that is a prefix of the
      // script's URI.
      if (libNode == null) {
        final service = serviceManager.service;
        final isolate = serviceManager.isolateManager.selectedIsolate.value;
        final libRef = serviceManager.isolateManager
            .isolateDebuggerState(isolate)
            .isolateNow
            .libraries
            .firstWhere(
              (lib) => script.uri.startsWith(lib.uri),
            );
        lib = await service.getObject(isolate.id, libRef.id);
      } else {
        lib = libNode.object as Library;
      }
      final ScriptRef s = (object is ScriptRef) ? object : script;
      uri = s.uri;
    }

    for (final clazz in lib.classes) {
      if (clazz.location.script.uri == uri) {
        final clazzNode = VMServiceObjectNode(
          controller,
          clazz.name,
          clazz,
        );
        if (clazz is Class) {
          for (final function in clazz.functions) {
            clazzNode._getCreateChild(function.name, function);
          }
          for (final field in clazz.fields) {
            clazzNode._getCreateChild(field.name, field);
          }
        }
        root.addChild(clazzNode);
      }
    }

    for (final function in lib.functions) {
      if (function.location.script.uri == uri) {
        final node = VMServiceObjectNode(
          controller,
          function.name,
          function,
        );
        await controller.populateNode(node);
        root.addChild(
          node,
        );
      }
    }

    for (final field in lib.variables) {
      if (field.location.script.uri == uri) {
        final node = VMServiceObjectNode(
          controller,
          field.name,
          field,
        );
        await controller.populateNode(node);
        root.addChild(
          VMServiceObjectNode(
            controller,
            field.name,
            field,
          ),
        );
      }
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    root._sortEntriesByType();
    _outline = root.children;
    return _outline;
  }

  /// Given a flat list of service protocol scripts, return a tree of scripts
  /// representing the best hierarchical grouping.
  static List<VMServiceObjectNode> createRootsFrom(
    ProgramExplorerController controller,
    List<VMServiceLibraryContents> libs,
  ) {
    // The name of this node is not exposed to users.
    final root = VMServiceObjectNode(controller, '<root>', ObjRef(id: '0'));

    for (var lib in libs) {
      for (final script in lib.lib.scripts) {
        _buildScriptNode(root, script, lib: lib.lib);
      }
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    // Sort each subtree to use the following ordering:
    //   - Scripts
    //   - Classes
    //   - Functions
    //   - Variables
    root._sortEntriesByType();

    return root.children;
  }

  static VMServiceObjectNode _buildScriptNode(
    VMServiceObjectNode node,
    ScriptRef script, {
    LibraryRef lib,
  }) {
    final parts = script.uri.split('/');
    print('building nodes: $parts');
    final name = parts.removeLast();

    for (final part in parts) {
      // Directory nodes shouldn't be selectable unless they're a library node.
      node = node._getCreateChild(
        part,
        null,
        isSelectable: false,
      );
      print('creating node: $part ${node.object} ${node.script}');
    }

    node = node._getCreateChild(name, script);
    if (!node.isSelectable) {
      node.isSelectable = true;
    }
    node.script = script;

    // If this is a top-level node and a library is specified, this must be a
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
      controller,
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
    final folderNodes = <VMServiceObjectNode>[];
    final libraryNodes = <VMServiceObjectNode>[];
    final scriptNodes = <VMServiceObjectNode>[];
    final classNodes = <VMServiceObjectNode>[];
    final functionNodes = <VMServiceObjectNode>[];
    final variableNodes = <VMServiceObjectNode>[];

    for (final child in children) {
      if (child.object == null && child.script == null) {
        // Child is a directory node. Treat it as if it were a library/script
        // for sorting purposes.
        print('folder: ${child.name}');
        folderNodes.add(child);
      } else {
        switch (child.object.runtimeType) {
          case ScriptRef:
          case Script:
            scriptNodes.add(child);
            break;
          case LibraryRef:
          case Library:
            libraryNodes.add(child);
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
      }
      child._sortEntriesByType();
    }

    folderNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    scriptNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    libraryNodes.sort((a, b) {
      return a.name.compareTo(b.name);
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
      ...libraryNodes,
      ...folderNodes,
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
