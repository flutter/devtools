// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to script objects in the Dart VM.
class VmScriptDisplay extends StatelessWidget {
  const VmScriptDisplay({
    required this.script,
  });

  final ScriptObject script;

  @override
  Widget build(BuildContext context) => VmObjectDisplayBasicLayout(
        object: script,
        generalDataRows: _scriptDataRows(script),
      );

  /// Generates a list of key-value pairs (map entries) containing the general
  /// VM information of the Script object [script].
  List<MapEntry<String, WidgetBuilder>> _scriptDataRows(
    ScriptObject field,
  ) {
    return [
      ...vmObjectGeneralDataRows(field),
      selectableTextBuilderMapEntry(
        'URI',
        script.obj.uri,
      ),
      selectableTextBuilderMapEntry(
        'Library',
        script.obj.library?.name?.isEmpty ?? false
            ? script.obj.uri
            : script.obj.library?.name,
      ),
      selectableTextBuilderMapEntry(
        'Load time',
        script.loadTime.toString(),
      ),
    ];
  }
}
