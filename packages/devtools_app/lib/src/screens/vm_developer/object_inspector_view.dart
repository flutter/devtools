// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/split.dart';
import '../debugger/program_explorer.dart';
import '../debugger/program_explorer_controller.dart';
import '../debugger/program_explorer_model.dart';
import 'object_viewport.dart';
import 'vm_developer_tools_screen.dart';

/// Displays a program explorer used to select and display information about objects in the Dart VM
class ObjectInspectorView extends VMDeveloperView {
  ObjectInspectorView()
      : super(
          id,
          title: 'Objects',
          icon: Icons.data_object,
        );
  static const id = 'inspector-view';

  final programExplorerController = ProgramExplorerController();

  ObjectHistory objectHistory = ObjectHistory();

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) {
    final programExplorerKey = GlobalKey(debugLabel: 'programExplorerKey');
    programExplorerController.initialize();
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.20, 0.80],
      children: [
        ProgramExplorer(
          key: programExplorerKey,
          controller: programExplorerController,
          onNodeSelected: _onNodeSelected,
          title: 'Program Explorer',
        ),
        ObjectViewport(
          controller: programExplorerController,
          objectHistory: objectHistory,
        )
      ],
    );
  }

  void _onNodeSelected(VMServiceObjectNode node) {
    final object = node.object;
    if (object != null) objectHistory.pushEntry(object);
    return;
  }
}
