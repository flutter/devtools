// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
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
    final scriptRef = script.scriptRef!;
    return ObjectInspectorCodeView(
      codeViewController: controller.codeViewController,
      script: scriptRef,
      object: scriptRef,
      child: VmObjectDisplayBasicLayout(
        object: script,
        generalDataRows: _scriptDataRows(script),
      ),
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
