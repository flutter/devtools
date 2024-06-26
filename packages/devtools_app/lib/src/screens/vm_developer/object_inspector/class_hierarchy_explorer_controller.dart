// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../../shared/primitives/trees.dart';

class ClassHierarchyExplorerController {
  ValueListenable<List<ClassHierarchyNode>> get selectedIsolateClassHierarchy =>
      _selectedIsolateClassHierarchy;
  final _selectedIsolateClassHierarchy =
      ValueNotifier<List<ClassHierarchyNode>>([]);

  Future<void> refresh() async {
    _selectedIsolateClassHierarchy.value = <ClassHierarchyNode>[];
    final service = serviceConnection.serviceManager.service!;
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    if (isolate == null) {
      return;
    }
    final isolateId = isolate.id!;
    final classList = await service.getClassList(isolateId);
    // TODO(bkonyi): we should cache the class list like we do the script list
    final classes = (await Future.wait([
      for (final cls in classList.classes!)
        service.getObject(isolateId, cls.id!).then((e) => e as Class),
    ]))
        .cast<Class>();

    buildHierarchy(classes);
  }

  @visibleForTesting
  void buildHierarchy(List<Class> classes) {
    final nodes = <String?, ClassHierarchyNode>{
      for (final cls in classes)
        cls.id: ClassHierarchyNode(
          cls: cls,
        ),
    };

    late final ClassHierarchyNode objectNode;
    for (final cls in classes) {
      if (cls.name == 'Object' && cls.library!.uri == 'dart:core') {
        objectNode = nodes[cls.id]!;
      }
      if (cls.superClass != null) {
        nodes[cls.superClass!.id]!.addChild(nodes[cls.id]!);
      }
    }

    breadthFirstTraversal<ClassHierarchyNode>(
      objectNode,
      action: (node) {
        node.children.sortBy<String>((element) => element.cls.name!);
      },
    );

    _selectedIsolateClassHierarchy.value = [objectNode];
  }
}

class ClassHierarchyNode extends TreeNode<ClassHierarchyNode> {
  ClassHierarchyNode({required this.cls});

  final Class cls;

  @override
  TreeNode<ClassHierarchyNode> shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
