// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';

import 'debugger_controller.dart';
import 'debugger_model.dart';

//const variablesKey = Key('debugger variables view');

class Variables extends StatelessWidget {
  const Variables({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    return ValueListenableBuilder<List<Variable>>(
      valueListenable: controller.variables,
      builder: (context, variables, _) {
//        final variableColumn = VariableColumn();
        if (variables.isEmpty) return const SizedBox();
        // TODO(kenz): display variables in a tree view.
        return const Center(child: Text('TODO'));
//        return TreeTable<Variable>(
//          key: variablesKey,
//          dataRoots: variables,
//          columns: [variableColumn],
//          treeColumn: variableColumn,
//          keyFactory: (variable) =>
//              PageStorageKey<String>(variable.boundVar.toString()),
//          includeHeader: false,
//        );
      },
    );
  }
}

//class VariableColumn extends TreeColumnData<Variable> {
//  VariableColumn() : super('Method');
//
//  @override
//  dynamic getValue(Variable dataObject) => dataObject.boundVar.value;
//
//  @override
//  String getDisplayValue(Variable dataObject) {
//    final name = dataObject.boundVar.name;
//    final value = dataObject.boundVar.value;
//
//    String valueStr;
//    if (value is InstanceRef) {
//      if (value.valueAsString == null) {
//        valueStr = value.classRef.name;
//      } else {
//        valueStr = value.valueAsString;
//        if (value.valueAsStringIsTruncated) {
//          valueStr += '...';
//        }
//        if (value.kind == InstanceKind.kString) {
//          valueStr = "'$valueStr'";
//        }
//      }
//
//      if (value.kind == InstanceKind.kList) {
//        valueStr = '[${value.length}] $valueStr';
//      } else if (value.kind == InstanceKind.kMap) {
//        valueStr = '{ ${value.length} } $valueStr';
//      } else if (value.kind != null && value.kind.endsWith('List')) {
//        // Uint8List, Uint16List, ...
//        valueStr = '[${value.length}] $valueStr';
//      }
//    } else if (value is Sentinel) {
//      valueStr = value.valueAsString;
//    } else if (value is TypeArgumentsRef) {
//      valueStr = value.name;
//    } else {
//      valueStr = value.toString();
//    }
//
//    return '$name: $valueStr';
//  }
//
//  @override
//  bool get supportsSorting => false;
//}
