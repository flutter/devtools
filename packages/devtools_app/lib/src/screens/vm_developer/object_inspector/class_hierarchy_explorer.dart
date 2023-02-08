// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/tree.dart';
import '../vm_developer_common_widgets.dart';
import 'class_hierarchy_explorer_controller.dart';
import 'object_inspector_view_controller.dart';

/// A widget that displays the class hierarchy for the currently selected
/// isolate, providing links for navigating within the object inspector.
///
/// The class hierarchy represents the inheritance structure of all classes in
/// a program. For example, all classes in Dart extend `Object` by default, so
/// `Object` acts as the root of the hierarchy. If we have classes `A`, `B`,
/// and `C`, where `B extends A`, the class hierarchy will be the following:
///
///   - Object
///     - A
///       - B
///     - C
class ClassHierarchyExplorer extends StatelessWidget {
  const ClassHierarchyExplorer({required this.controller});

  final ObjectInspectorViewController controller;

  @override
  Widget build(BuildContext context) {
    return TreeView<ClassHierarchyNode>(
      dataRootsListenable:
          controller.classHierarchyController.selectedIsolateClassHierarchy,
      dataDisplayProvider: (node, onPressed) => VmServiceObjectLink<Class>(
        object: node.cls,
        onTap: (cls) => unawaited(
          controller.findAndSelectNodeForObject(context, cls),
        ),
      ),
      onItemSelected: (_) => null,
      emptyTreeViewBuilder: () => const CenteredCircularProgressIndicator(),
    );
  }
}
