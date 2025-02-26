// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to script objects in the Dart VM.
class VmScriptDisplay extends StatelessWidget {
  const VmScriptDisplay({
    super.key,
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
        controller: controller,
        object: script,
        generalDataRows: _scriptDataRows(script),
      ),
    );
  }

  /// Generates a list of key-value pairs (map entries) containing the general
  /// VM information of the Script object `widget.script`.
  List<MapEntry<String, WidgetBuilder>> _scriptDataRows(ScriptObject field) {
    return [
      ...vmObjectGeneralDataRows(controller, field),
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'URI',
        object: script.obj,
      ),
      selectableTextBuilderMapEntry('Load time', script.loadTime.toString()),
    ];
  }
}
