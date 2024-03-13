// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/trees.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'debugger_model.dart';
import 'program_explorer_controller.dart';

/// A node in a tree of VM service objects.
///
/// A node can represent one of the following:
///   - Directory
///   - Library (with or without a script)
///   - Script
///   - Class
///   - Field
///   - Function
///   - Code
class VMServiceObjectNode extends TreeNode<VMServiceObjectNode> {
  VMServiceObjectNode(
    this.controller,
    String? name,
    this.object, {
    this.isSelectable = true,
  }) : name = name ?? '';

  static const dartPrefix = 'dart:';
  static const packagePrefix = 'package:';

  final ProgramExplorerController controller;
  final String name;
  bool isSelectable;

  ObjRef? object;
  ScriptRef? script;
  ScriptLocation? location;

  /// This exists to allow for O(1) lookup of children when building the tree.
  final _childrenAsMap = <String, VMServiceObjectNode>{};

  @override
  bool shouldShow() {
    return true;
  }

  // TODO(bkonyi): handle empty classes
  @override
  bool get isExpandable => super.isExpandable || object is ClassRef;

  bool get isDirectory => script == null && object == null;

  List<VMServiceObjectNode>? _outline;
  Future<List<VMServiceObjectNode>?> get outline async {
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
      uri = lib.uri ?? '';
    } else {
      // Try to find the library in the tree. If the current node isn't a
      // library node, it's likely one of its parents are.
      VMServiceObjectNode? libNode = this;
      while (libNode != null && libNode.object is! Library) {
        libNode = libNode.parent;
      }

      // In the case of patch files, the parent nodes won't include a library.
      // We'll need to search for the library URI that is a prefix of the
      // script's URI.
      if (libNode == null) {
        final service = serviceConnection.serviceManager.service!;
        final isolate = serviceConnection
            .serviceManager.isolateManager.selectedIsolate.value!;
        final libRef = serviceConnection.serviceManager.isolateManager
            .isolateState(isolate)
            .isolateNow!
            .libraries!
            .firstWhere(
              (lib) => script!.uri!.startsWith(lib.uri!),
            );
        lib = await service.getObject(isolate.id!, libRef.id!) as Library;
      } else {
        lib = libNode.object as Library;
      }
      final ScriptRef s = (object is ScriptRef) ? object as ScriptRef : script!;
      uri = s.uri ?? '';
    }

    for (final clazzRef in lib.classes!) {
      // Don't surface synthetic classes created by mixin applications.
      if (clazzRef.name!.contains('&')) {
        continue;
      }
      if (clazzRef.location?.script?.uri == uri) {
        final clazzNode = VMServiceObjectNode(
          controller,
          clazzRef.name,
          clazzRef,
        );
        await controller.populateNode(clazzNode);
        root.addChild(clazzNode);
      }
    }
    for (final function in lib.functions!) {
      if (function.location?.script?.uri == uri) {
        final node = VMServiceObjectNode(
          controller,
          function.name,
          function,
        );
        await controller.populateNode(node);
        _buildCodeNodes(node.object as Func, node);
        root.addChild(node);
      }
    }

    for (final field in lib.variables!) {
      if (field.location?.script?.uri == uri) {
        final node = VMServiceObjectNode(
          controller,
          field.name,
          field,
        );
        await controller.populateNode(node);
        root.addChild(node);
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
    List<LibraryRef> libs,
  ) {
    if (libs.isEmpty) {
      return [];
    }
    // The name of this node is not exposed to users.
    final root = VMServiceObjectNode(controller, '<root>', ObjRef(id: '0'));

    final scripts = scriptManager.sortedScripts.value;

    for (final script in scripts) {
      _buildScriptNode(root, script);
    }

    for (final lib in libs) {
      for (final child in root.children) {
        if (child.script?.uri == lib.uri) {
          child.object = lib;
        }
      }
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    final processed = root.children
        .map((e) => e._collapseSingleChildDirectoryNodes())
        .toList();
    root.children.clear();
    root.addAllChildren(processed);

    // Sort each subtree to use the following ordering:
    //   - Scripts
    //   - Classes
    //   - Functions
    //   - Variables
    root._sortEntriesByType();

    // Place the root library's parent node at the top of the explorer if it's
    // part of a package. Otherwise, it's a file path and its directory should
    // appear near the top of the list anyway.
    final rootLibUri = serviceConnection.serviceManager.isolateManager
        .mainIsolateState?.isolateNow?.rootLib?.uri;
    if (rootLibUri != null) {
      if (rootLibUri.startsWith('package:') ||
          rootLibUri.startsWith('google3:')) {
        final parts = rootLibUri.split('/')..removeLast();
        final path = parts.join('/');
        for (int i = 0; i < root.children.length; ++i) {
          if (root.children[i].name.startsWith(path)) {
            final VMServiceObjectNode rootLibNode = root.removeChildAtIndex(i);
            root.addChild(rootLibNode, index: 0);
            break;
          }
        }
      }
    }

    return root.children;
  }

  static VMServiceObjectNode _buildScriptNode(
    VMServiceObjectNode node,
    ScriptRef script, {
    LibraryRef? lib,
  }) {
    final parts = script.uri!.split('/');
    final name = parts.removeLast();

    for (final part in parts) {
      // Directory nodes shouldn't be selectable unless they're a library node.
      node = node._lookupOrCreateChild(
        part,
        null,
        isSelectable: false,
      );
    }

    node = node._lookupOrCreateChild(name, script);
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

  void _buildCodeNodes(Func function, VMServiceObjectNode node) {
    if (!node.controller.showCodeNodes) {
      return;
    }
    final code = function.code;
    if (code != null) {
      node.addChild(
        VMServiceObjectNode(
          controller,
          code.name,
          code,
        ),
      );
      final unoptimizedCode = function.unoptimizedCode;
      // It's possible for `function.code` to be unoptimized code, so don't
      // create a duplicate node in that situation.
      if (unoptimizedCode != null && unoptimizedCode.id! != code.id!) {
        node.addChild(
          VMServiceObjectNode(
            controller,
            unoptimizedCode.name,
            unoptimizedCode,
          ),
        );
      }
    }
  }

  VMServiceObjectNode _lookupOrCreateChild(
    String name,
    ObjRef? object, {
    bool isSelectable = true,
  }) {
    return _childrenAsMap.putIfAbsent(
      name,
      () => _createChild(name, object, isSelectable: isSelectable),
    );
  }

  VMServiceObjectNode _createChild(
    String? name,
    ObjRef? object, {
    bool isSelectable = true,
  }) {
    final child = VMServiceObjectNode(
      controller,
      name,
      object,
      isSelectable: isSelectable,
    );
    addChild(child);
    return child;
  }

  VMServiceObjectNode _collapseSingleChildDirectoryNodes() {
    if (children.length == 1) {
      final VMServiceObjectNode child = children.first;
      if (child.isDirectory) {
        final collapsed = VMServiceObjectNode(
          controller,
          '$name/${child.name}',
          null,
          isSelectable: false,
        );
        collapsed.addAllChildren(child.children);
        return collapsed._collapseSingleChildDirectoryNodes();
      }
      return this;
    }
    final updated = children
        .map(
          (e) => e._collapseSingleChildDirectoryNodes(),
        )
        .toList();
    children.clear();
    addAllChildren(updated);
    return this;
  }

  void updateObject(Obj object, {bool forceUpdate = false}) {
    if ((this.object is! Class || forceUpdate) && object is Class) {
      for (final function in object.functions?.cast<Func>() ?? <Func>[]) {
        final node = _createChild(function.name, function);
        _buildCodeNodes(function, node);
      }
      for (final field in object.fields ?? <FieldRef>[]) {
        _createChild(field.name, field);
      }
      _sortEntriesByType();
    }
    this.object = object;
  }

  Future<void> populateLocation() async {
    if (location != null) {
      return;
    }
    ScriptRef? scriptRef = script;
    int? tokenPos = 0;
    final object = this.object;

    final SourceLocation? sourceLocation = switch (object) {
      FieldRef(:final location) ||
      FuncRef(:final location) ||
      ClassRef(:final location) =>
        location,
      _ => null,
    };

    if (sourceLocation != null) {
      tokenPos = sourceLocation.tokenPos;
      scriptRef = sourceLocation.script;
    }

    if (scriptRef != null) {
      final fetchedScript = await scriptManager.getScript(scriptRef);
      final position = tokenPos == 0
          ? null
          : SourcePosition.calculatePosition(fetchedScript, tokenPos!);

      location = ScriptLocation(
        scriptRef,
        location: position,
      );
    }
  }

  /// Clear the _childrenAsMap map recursively to save memory.
  void _trimChildrenAsMapEntries() {
    _childrenAsMap.clear();

    for (var child in children) {
      child._trimChildrenAsMapEntries();
    }
  }

  void _sortEntriesByType() {
    final userDirectoryNodes = <VMServiceObjectNode>[];
    final userLibraryNodes = <VMServiceObjectNode>[];
    final scriptNodes = <VMServiceObjectNode>[];
    final classNodes = <VMServiceObjectNode>[];
    final functionNodes = <VMServiceObjectNode>[];
    final variableNodes = <VMServiceObjectNode>[];
    final codeNodes = <VMServiceObjectNode>[];

    final packageAndCoreLibLibraryNodes = <VMServiceObjectNode>[];
    final packageAndCoreLibDirectoryNodes = <VMServiceObjectNode>[];

    for (final child in children) {
      if (child.object == null && child.script == null) {
        // Child is a directory node. Treat it as if it were a library/script
        // for sorting purposes.
        if (child.name.startsWith(dartPrefix) ||
            child.name.startsWith(packagePrefix)) {
          packageAndCoreLibDirectoryNodes.add(child);
        } else {
          userDirectoryNodes.add(child);
        }
      } else {
        switch (child.object.runtimeType) {
          case ScriptRef:
          case Script:
            scriptNodes.add(child);
            break;
          case LibraryRef:
          case Library:
            final obj = child.object as LibraryRef;
            if (obj.uri!.startsWith(dartPrefix) ||
                obj.uri!.startsWith(packagePrefix)) {
              packageAndCoreLibLibraryNodes.add(child);
            } else {
              userLibraryNodes.add(child);
            }
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
          case CodeRef:
          case Code:
            codeNodes.add(child);
            break;
          default:
            throw StateError('Unexpected type: ${child.object.runtimeType}');
        }
      }
      child._sortEntriesByType();
    }

    userDirectoryNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    scriptNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    userLibraryNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    classNodes.sort((a, b) {
      final objA = a.object as ClassRef;
      final objB = b.object as ClassRef;
      return objA.name!.compareTo(objB.name!);
    });

    functionNodes.sort((a, b) {
      final objA = a.object as FuncRef;
      final objB = b.object as FuncRef;
      return objA.name!.compareTo(objB.name!);
    });

    variableNodes.sort((a, b) {
      final objA = a.object as FieldRef;
      final objB = b.object as FieldRef;
      return objA.name!.compareTo(objB.name!);
    });

    packageAndCoreLibDirectoryNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    packageAndCoreLibLibraryNodes.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    children
      ..clear()
      ..addAll([
        ...userLibraryNodes,
        ...userDirectoryNodes,
        ...scriptNodes,
        ...classNodes,
        ...functionNodes,
        ...variableNodes,
        ...codeNodes,
        // We treat core libraries and packages as their own category as users
        // are likely more interested in code within their own project.
        // TODO(bkonyi): do we need custom google3 heuristics here?
        ...packageAndCoreLibLibraryNodes,
        ...packageAndCoreLibDirectoryNodes,
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
