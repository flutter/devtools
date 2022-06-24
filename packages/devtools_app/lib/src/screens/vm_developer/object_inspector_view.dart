// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/split.dart';
import '../debugger/program_explorer.dart';
import '../debugger/program_explorer_controller.dart';
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
  final controller = ObjectInspectorViewController();

  final programExplorerController = ProgramExplorerController();

  @override
  State<StatefulWidget> createState() => _ObjectInspectorViewState();

  State<StatefulWidget> initState() {
    programExplorerController.initialize();
    return _ObjectInspectorViewState();
  }
}

class _ObjectInspectorViewState extends State<_ObjectInspectorView> {
  @override
  Widget build(BuildContext context) {
    widget.programExplorerController.initialize();
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.20, 0.80],
      children: [
        ProgramExplorer(
          controller: widget.programExplorerController,
          onNodeSelected: _onNodeSelected,
          title: 'Program Explorer',
        ),
        ObjectViewport(
          controller: widget.controller,
        )
      ],
    );
  }

  void _onNodeSelected(VMServiceObjectNode node) {
    final objRef = node.object;
    if (objRef != null) {
      widget.controller.pushObject(objRef);
    }
  }
}
