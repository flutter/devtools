// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/ui/drop_down_button.dart';
import '../../debugger/program_explorer.dart';
import '../../debugger/program_explorer_model.dart';
import '../vm_developer_tools_controller.dart';
import '../vm_developer_tools_screen.dart';
import 'class_hierarchy_explorer.dart';
import 'object_inspector_view_controller.dart';
import 'object_store.dart';
import 'object_viewport.dart';

/// Displays a program explorer and a history viewport that displays
/// information about objects in the Dart VM.
class ObjectInspectorView extends VMDeveloperView {
  ObjectInspectorView()
      : super(
          title: 'Objects',
          icon: Icons.data_object_outlined,
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

class _ObjectInspectorViewState extends State<_ObjectInspectorView>
    with TickerProviderStateMixin {
  late ObjectInspectorViewController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vmDeveloperToolsController =
        Provider.of<VMDeveloperToolsController>(context);
    controller = vmDeveloperToolsController.objectInspectorViewController;
    unawaited(controller.init());
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.2, 0.8],
      children: [
        const ObjectInspectorSelector(),
        SelectionArea(
          child: ObjectViewport(
            controller: controller,
          ),
        ),
      ],
    );
  }
}

class ObjectInspectorSelector extends StatefulWidget {
  const ObjectInspectorSelector({
    super.key,
  });

  static const kProgramExplorer = 'Program Explorer';
  static const kObjectStore = 'Object Store';
  static const kClassHierarchy = 'Class Hierarchy';

  @override
  State<ObjectInspectorSelector> createState() =>
      _ObjectInspectorSelectorState();
}

class _ObjectInspectorSelectorState extends State<ObjectInspectorSelector> {
  String value = ObjectInspectorSelector.kProgramExplorer;
  late ObjectInspectorViewController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vmDeveloperToolsController =
        Provider.of<VMDeveloperToolsController>(context);
    controller = vmDeveloperToolsController.objectInspectorViewController;
    unawaited(controller.init());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnalyticsDropDownButton<String>(
          gaScreen: gac.objectInspectorScreen,
          gaDropDownId: gac.objectInspectorDropDown,
          message: '',
          isExpanded: true,
          value: value,
          roundedCornerOptions: const RoundedCornerOptions(
            showBottomLeft: false,
            showBottomRight: false,
          ),
          items: [
            _buildMenuItem(
              ObjectInspectorSelector.kProgramExplorer,
              gac.programExplorer,
            ),
            _buildMenuItem(
              ObjectInspectorSelector.kObjectStore,
              gac.objectStore,
            ),
            _buildMenuItem(
              ObjectInspectorSelector.kClassHierarchy,
              gac.classHierarchy,
            ),
          ],
          onChanged: (newValue) => setState(() {
            value = newValue!;
          }),
        ),
        Expanded(
          child: RoundedOutlinedBorder(
            showTopLeft: false,
            showTopRight: false,
            child: _selectedWidget(),
          ),
        ),
      ],
    );
  }

  ({DropdownMenuItem<String> item, String gaId}) _buildMenuItem(
    String text,
    String gaId,
  ) {
    return (
      item: DropdownMenuItem<String>(
        value: text,
        child: Text(text),
      ),
      gaId: gaId,
    );
  }

  Widget _selectedWidget() {
    switch (value) {
      case ObjectInspectorSelector.kProgramExplorer:
        return ProgramExplorer(
          controller: controller.programExplorerController,
          onNodeSelected: _onNodeSelected,
          displayHeader: false,
        );
      case ObjectInspectorSelector.kObjectStore:
        return ObjectStoreViewer(
          controller: controller.objectStoreController,
          onLinkTapped: controller.findAndSelectNodeForObject,
        );
      case ObjectInspectorSelector.kClassHierarchy:
        return ClassHierarchyExplorer(
          controller: controller,
        );
      default:
        throw StateError('Unexpected value: $value');
    }
  }

  void _onNodeSelected(VMServiceObjectNode node) {
    final objRef = node.object;
    final location = node.location;
    if (objRef != null &&
        objRef != controller.objectHistory.current.value?.ref) {
      unawaited(controller.pushObject(objRef, scriptRef: location?.scriptRef));
    }
  }
}
