// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_common_widgets.dart';
import '../vm_service_private_extensions.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

// TODO(mtaylee): Finish implementation of [ICDataArrayWidget] and add it to
// the [VmFuncDisplay].

/// A widget for the object inspector historyViewport displaying information
/// related to function (Func type) objects in the Dart VM.
class VmFuncDisplay extends StatelessWidget {
  const VmFuncDisplay({
    super.key,
    required this.controller,
    required this.function,
  });

  final ObjectInspectorViewController controller;
  final FuncObject function;

  @override
  Widget build(BuildContext context) {
    return ObjectInspectorCodeView(
      codeViewController: controller.codeViewController,
      script: function.scriptRef!,
      object: function.obj,
      child: VmObjectDisplayBasicLayout(
        controller: controller,
        object: function,
        generalDataRows: vmObjectGeneralDataRows(controller, function),
        sideCardDataRows: _functionDetailRows(function),
        sideCardTitle: 'Function Details',
        expandableWidgets: [
          if (function.icDataArray != null)
            CallSiteDataArrayWidget(
              controller: controller,
              callSiteDataArray: function.icDataArray!,
            ),
        ],
      ),
    );
  }

  /// Returns a list of key-value pairs (map entries)
  /// containing detailed information of a VM Func object [function].
  List<MapEntry<String, Widget Function(BuildContext)>> _functionDetailRows(
    FuncObject function,
  ) {
    String? boolYesOrNo(bool? condition) {
      if (condition == null) {
        return null;
      }
      return condition ? 'Yes' : 'No';
    }

    return [
      selectableTextBuilderMapEntry('Kind', _kindDescription(function.kind)),
      selectableTextBuilderMapEntry(
        'Deoptimizations',
        function.deoptimizations?.toString(),
      ),
      selectableTextBuilderMapEntry(
        'Optimizable',
        boolYesOrNo(function.isOptimizable),
      ),
      selectableTextBuilderMapEntry(
        'Inlinable',
        boolYesOrNo(function.isInlinable),
      ),
      selectableTextBuilderMapEntry(
        'Intrinsic',
        boolYesOrNo(function.hasIntrinsic),
      ),
      selectableTextBuilderMapEntry(
        'Recognized',
        boolYesOrNo(function.isRecognized),
      ),
      selectableTextBuilderMapEntry('Native', boolYesOrNo(function.isNative)),
      selectableTextBuilderMapEntry('VM Name', function.vmName),
    ];
  }

  String? _kindDescription(FunctionKind? funcKind) {
    if (funcKind == null) {
      return 'Unrecognized function kind: ${function.obj.kind}';
    }

    final kind = StringBuffer();

    void addSpace() => kind.write(kind.isNotEmpty ? ' ' : '');

    if (function.obj.isStatic == true) {
      kind.write('static');
    }

    if (function.obj.isConst == true) {
      addSpace();
      kind.write('const');
    }

    addSpace();

    kind.write(funcKind.kindDescription().toLowerCase());

    return kind.toString();
  }
}

class CallSiteDataArrayWidget extends StatelessWidget {
  const CallSiteDataArrayWidget({
    super.key,
    required this.controller,
    required this.callSiteDataArray,
  });

  final ObjectInspectorViewController controller;
  final Instance callSiteDataArray;

  @override
  Widget build(BuildContext context) {
    return VmExpansionTile(
      title: 'Call Site Data (${callSiteDataArray.length})',
      children: prettyRows(context, [
        for (final entry in callSiteDataArray.elements!)
          Row(
            children: [
              VmServiceObjectLink(
                object: entry as ObjRef,
                onTap: controller.findAndSelectNodeForObject,
              ),
            ],
          ),
      ]),
    );
  }
}
