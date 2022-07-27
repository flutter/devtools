// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/split.dart';
import '../debugger/program_explorer.dart';
import '../debugger/program_explorer_model.dart';
import 'object_inspector_view_controller.dart';
import 'object_viewport.dart';
import 'vm_developer_tools_screen.dart';

/// Displays a program explorer and a history viewport that displays
/// information about objects in the Dart VM.
class ObjectInspectorView extends VMDeveloperView {
  ObjectInspectorView()
      : super(
          id,
          title: 'Objects',
          icon: Icons.data_object,
        );
  static const id = 'object-inspector-view';

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) => _ObjectInspectorView();
}

class _ObjectInspectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ObjectInspectorViewState();
}

class _ObjectInspectorViewState extends State<_ObjectInspectorView> {
  late final ObjectInspectorViewController controller;

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    controller = ObjectInspectorViewController()..init();
=======
    controller = ObjectInspectorViewController();
    programExplorerController = ProgramExplorerController(showCodeNodes: true)
      ..initialize();
>>>>>>> master
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.20, 0.80],
      children: [
        ProgramExplorer(
          controller: controller.programExplorerController,
          onNodeSelected: _onNodeSelected,
          title: 'Program Explorer',
        ),
        ObjectViewport(
          controller: controller,
        )
      ],
    );
  }

  void _onNodeSelected(VMServiceObjectNode node) {
    final objRef = node.object;
    final location = node.location;

    if (location != null) {
      controller.setCurrentScript(location.scriptRef);
    }

    if (objRef != null &&
        objRef != controller.objectHistory.current.value?.ref) {
      controller.pushObject(objRef);
    }
  }
}
