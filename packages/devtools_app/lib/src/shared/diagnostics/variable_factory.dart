// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:vm_service/vm_service.dart';

import '../primitives/utils.dart';
import 'values_node.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';

List<ValuesNode> createVariablesForStackTrace(
  Instance stackTrace,
  IsolateRef? isolateRef,
) {
  final trace = stack_trace.Trace.parse(stackTrace.valueAsString!);
  return [
    for (int i = 0; i < trace.frames.length; ++i)
      ValuesNode.fromValue(
        name: '[$i]',
        value: trace.frames[i].toString(),
        isolateRef: isolateRef,
        artificialName: true,
        artificialValue: true,
      ),
  ];
}

List<ValuesNode> createVariablesForParameter(
  Parameter parameter,
  IsolateRef? isolateRef,
) {
  return [
    if (parameter.name != null)
      ValuesNode.fromString(
        name: 'name',
        value: parameter.name,
        isolateRef: isolateRef,
      ),
    ValuesNode.fromValue(
      name: 'required',
      value: parameter.required ?? false,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'type',
      value: parameter.parameterType,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForContext(
  Context context,
  IsolateRef isolateRef,
) {
  return [
    ValuesNode.fromValue(
      name: 'length',
      value: context.length,
      isolateRef: isolateRef,
    ),
    if (context.parent != null)
      ValuesNode.fromValue(
        name: 'parent',
        value: context.parent,
        isolateRef: isolateRef,
      ),
    ValuesNode.fromList(
      name: 'variables',
      type: '_ContextElement',
      list: context.variables,
      displayNameBuilder: (Object? e) => (e as ContextElement).value,
      artificialChildValues: false,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForFunc(
  Func function,
  IsolateRef isolateRef,
) {
  return [
    ValuesNode.fromString(
      name: 'name',
      value: function.name,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'signature',
      value: function.signature,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'owner',
      value: function.owner,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
  ];
}

List<ValuesNode> createVariablesForWeakProperty(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesNode.fromValue(
      name: 'key',
      value: result.propertyKey,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'value',
      value: result.propertyValue,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForTypeParameters(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    // TODO(bkonyi): determine if we want to display this and add
    // support for displaying Class objects.
    // DartObjectNode.fromValue(
    //   name: 'parameterizedClass',
    //   value: result.parameterizedClass,
    //   isolateRef: isolateRef,
    // ),
    ValuesNode.fromValue(
      name: 'index',
      value: result.parameterIndex,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'bound',
      value: result.bound,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForFunctionType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesNode.fromValue(
      name: 'returnType',
      value: result.returnType,
      isolateRef: isolateRef,
    ),
    if (result.typeParameters != null)
      ValuesNode.fromValue(
        name: 'typeParameters',
        value: result.typeParameters,
        isolateRef: isolateRef,
      ),
    ValuesNode.fromList(
      name: 'parameters',
      type: '_Parameters',
      list: result.parameters,
      displayNameBuilder: (e) => '_Parameter',
      childBuilder: (e) {
        final parameter = e as Parameter;
        return [
          if (parameter.name != null) ...[
            ValuesNode.fromString(
              name: 'name',
              value: parameter.name,
              isolateRef: isolateRef,
            ),
            ValuesNode.fromValue(
              name: 'required',
              value: parameter.required,
              isolateRef: isolateRef,
            ),
          ],
          ValuesNode.fromValue(
            name: 'type',
            value: parameter.parameterType,
            isolateRef: isolateRef,
          ),
        ];
      },
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesNode.fromString(
      name: 'name',
      value: result.name,
      isolateRef: isolateRef,
    ),
    // TODO(bkonyi): determine if we want to display this and add
    // support for displaying Class objects.
    // DartObjectNode.fromValue(
    //   name: 'typeClass',
    //   value: result.typeClass,
    //   isolateRef: isolateRef,
    // ),
    if (result.typeArguments != null)
      ValuesNode.fromValue(
        name: 'typeArguments',
        value: result.typeArguments,
        isolateRef: isolateRef,
      ),
    if (result.targetType != null)
      ValuesNode.fromValue(
        name: 'targetType',
        value: result.targetType,
        isolateRef: isolateRef,
      ),
  ];
}

List<ValuesNode> createVariablesForReceivePort(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    if (result.debugName!.isNotEmpty)
      ValuesNode.fromString(
        name: 'debugName',
        value: result.debugName,
        isolateRef: isolateRef,
      ),
    ValuesNode.fromValue(
      name: 'portId',
      value: result.portId,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'allocationLocation',
      value: result.allocationLocation,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesNode> createVariablesForClosure(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesNode.fromValue(
      name: 'function',
      value: result.closureFunction,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
    ValuesNode.fromValue(
      name: 'context',
      value: result.closureContext,
      isolateRef: isolateRef,
      artificialValue: result.closureContext != null,
    ),
  ];
}

List<ValuesNode> createVariablesForRegExp(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesNode.fromValue(
      name: 'pattern',
      value: result.pattern,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'isCaseSensitive',
      value: result.isCaseSensitive,
      isolateRef: isolateRef,
    ),
    ValuesNode.fromValue(
      name: 'isMultiline',
      value: result.isMultiLine,
      isolateRef: isolateRef,
    ),
  ];
}

Future<ValuesNode> _buildVariable(
  RemoteDiagnosticsNode diagnostic,
  ObjectGroupBase inspectorService,
  IsolateRef? isolateRef,
) async {
  final instanceRef =
      await inspectorService.toObservatoryInstanceRef(diagnostic.valueRef);
  return ValuesNode.fromValue(
    name: diagnostic.name,
    value: instanceRef,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
  );
}

Future<List<ValuesNode>> createVariablesForDiagnostics(
  ObjectGroupBase inspectorService,
  List<RemoteDiagnosticsNode> diagnostics,
  IsolateRef isolateRef,
) async {
  final variables = <Future<ValuesNode>>[];
  for (var diagnostic in diagnostics) {
    // Omit hidden properties.
    if (diagnostic.level == DiagnosticLevel.hidden) continue;
    variables.add(_buildVariable(diagnostic, inspectorService, isolateRef));
  }
  return variables.isNotEmpty ? await Future.wait(variables) : const [];
}

List<ValuesNode> createVariablesForAssociations(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <ValuesNode>[];
  final associations = instance.associations ?? [];

  // If the key type for the provided associations is not primitive, we want to
  // allow for users to drill down into the key object's properties. If we're
  // only dealing with primative types as keys, we can render a flatter
  // representation.
  final hasPrimitiveKey = associations.fold<bool>(
    false,
    (p, e) => p || isPrimativeInstanceKind(e.key.kind),
  );
  for (var i = 0; i < associations.length; i++) {
    final association = associations[i];
    if (association.key is! InstanceRef) {
      continue;
    }
    if (hasPrimitiveKey) {
      variables.add(
        ValuesNode.fromValue(
          name: association.key.valueAsString,
          value: association.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      final key = ValuesNode.fromValue(
        name: '[key]',
        value: association.key,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final value = ValuesNode.fromValue(
        name: '[value]',
        value: association.value,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final entryNum = instance.offset == null ? i : i + instance.offset!;
      variables.add(
        ValuesNode.text('[Entry $entryNum]')
          ..addChild(key)
          ..addChild(value),
      );
    }
  }
  return variables;
}

/// Decodes the bytes into the correctly sized values based on
/// [Instance.kind], falling back to raw bytes if a type is not
/// matched.
///
/// This method does not currently support [Uint64List] or
/// [Int64List].
List<ValuesNode> createVariablesForBytes(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final bytes = base64.decode(instance.bytes!);
  final variables = <ValuesNode>[];
  List<Object?> result;
  switch (instance.kind) {
    case InstanceKind.kUint8ClampedList:
    case InstanceKind.kUint8List:
      result = bytes;
      break;
    case InstanceKind.kUint16List:
      result = Uint16List.view(bytes.buffer);
      break;
    case InstanceKind.kUint32List:
      result = Uint32List.view(bytes.buffer);
      break;
    case InstanceKind.kUint64List:
      // TODO: https://github.com/flutter/devtools/issues/2159
      if (kIsWeb) {
        return <ValuesNode>[];
      }
      result = Uint64List.view(bytes.buffer);
      break;
    case InstanceKind.kInt8List:
      result = Int8List.view(bytes.buffer);
      break;
    case InstanceKind.kInt16List:
      result = Int16List.view(bytes.buffer);
      break;
    case InstanceKind.kInt32List:
      result = Int32List.view(bytes.buffer);
      break;
    case InstanceKind.kInt64List:
      // TODO: https://github.com/flutter/devtools/issues/2159
      if (kIsWeb) {
        return <ValuesNode>[];
      }
      result = Int64List.view(bytes.buffer);
      break;
    case InstanceKind.kFloat32List:
      result = Float32List.view(bytes.buffer);
      break;
    case InstanceKind.kFloat64List:
      result = Float64List.view(bytes.buffer);
      break;
    case InstanceKind.kInt32x4List:
      result = Int32x4List.view(bytes.buffer);
      break;
    case InstanceKind.kFloat32x4List:
      result = Float32x4List.view(bytes.buffer);
      break;
    case InstanceKind.kFloat64x2List:
      result = Float64x2List.view(bytes.buffer);
      break;
    default:
      result = bytes;
  }

  for (int i = 0; i < result.length; i++) {
    final name = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      ValuesNode.fromValue(
        name: '[$name]',
        value: result[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<ValuesNode> createVariablesForElements(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <ValuesNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final name = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      ValuesNode.fromValue(
        name: '[$name]',
        value: elements[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<ValuesNode> createVariablesForFields(
  Instance instance,
  IsolateRef? isolateRef, {
  Set<String>? existingNames,
}) {
  final variables = <ValuesNode>[];
  for (var field in instance.fields!) {
    final name = field.decl?.name;
    if (name == null) {
      variables.add(
        ValuesNode.fromValue(
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      if (existingNames != null && existingNames.contains(name)) continue;
      variables.add(
        ValuesNode.fromValue(
          name: name,
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    }
  }
  return variables;
}
