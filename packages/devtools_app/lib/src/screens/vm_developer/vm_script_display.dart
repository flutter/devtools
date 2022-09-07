// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

<<<<<<< HEAD
=======
import '../../shared/common_widgets.dart';
import '../../shared/split.dart';
>>>>>>> 99b20824 (Add "Code Preview" section to Object Inspector views)
import 'object_inspector_view_controller.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to script objects in the Dart VM.
class VmScriptDisplay extends StatelessWidget {
  const VmScriptDisplay({
    required this.controller,
    required this.script,
  });

  final ObjectInspectorViewController controller;
  final ScriptObject script;

  @override
  Widget build(BuildContext context) {
    final debuggerController = controller.debuggerController;
    final scriptRef = script.scriptRef!;
    return Split(
      initialFractions: const [0.5, 0.5],
      axis: Axis.vertical,
      children: [
        OutlineDecoration(
          showLeft: false,
          showRight: false,
          showTop: false,
          child: VmObjectDisplayBasicLayout(
            object: script,
            generalDataRows: _scriptDataRows(script),
          ),
        ),
        ObjectInspectorCodeView(
          debuggerController: debuggerController,
          script: scriptRef,
          object: scriptRef,
        ),
      ],
    );
  }

  /// Generates a list of key-value pairs (map entries) containing the general
  /// VM information of the Script object [widget.script].
  List<MapEntry<String, WidgetBuilder>> _scriptDataRows(
    ScriptObject field,
  ) {
    return [
      ...vmObjectGeneralDataRows(
        controller,
        field,
      ),
      serviceObjectLinkBuilderMapEntry<ScriptRef>(
        controller: controller,
        key: 'URI',
        object: script.obj,
      ),
      selectableTextBuilderMapEntry(
        'Load time',
        script.loadTime.toString(),
      ),
    ];
  }
}
