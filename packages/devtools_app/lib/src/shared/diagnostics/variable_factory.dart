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
import 'values_object_node.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';

List<ValuesObjectNode> createVariablesForStackTrace(
  Instance stackTrace,
  IsolateRef? isolateRef,
) {
  final trace = stack_trace.Trace.parse(stackTrace.valueAsString!);
  return [
    for (int i = 0; i < trace.frames.length; ++i)
      ValuesObjectNode.fromValue(
        name: '[$i]',
        value: trace.frames[i].toString(),
        isolateRef: isolateRef,
        artificialName: true,
        artificialValue: true,
      ),
  ];
}

List<ValuesObjectNode> createVariablesForParameter(
  Parameter parameter,
  IsolateRef? isolateRef,
) {
  return [
    if (parameter.name != null)
      ValuesObjectNode.fromString(
        name: 'name',
        value: parameter.name,
        isolateRef: isolateRef,
      ),
    ValuesObjectNode.fromValue(
      name: 'required',
      value: parameter.required ?? false,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'type',
      value: parameter.parameterType,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForContext(
  Context context,
  IsolateRef isolateRef,
) {
  return [
    ValuesObjectNode.fromValue(
      name: 'length',
      value: context.length,
      isolateRef: isolateRef,
    ),
    if (context.parent != null)
      ValuesObjectNode.fromValue(
        name: 'parent',
        value: context.parent,
        isolateRef: isolateRef,
      ),
    ValuesObjectNode.fromList(
      name: 'variables',
      type: '_ContextElement',
      list: context.variables,
      displayNameBuilder: (Object? e) => (e as ContextElement).value,
      artificialChildValues: false,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForFunc(
  Func function,
  IsolateRef isolateRef,
) {
  return [
    ValuesObjectNode.fromString(
      name: 'name',
      value: function.name,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'signature',
      value: function.signature,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'owner',
      value: function.owner,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForWeakProperty(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesObjectNode.fromValue(
      name: 'key',
      value: result.propertyKey,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'value',
      value: result.propertyValue,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForTypeParameters(
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
    ValuesObjectNode.fromValue(
      name: 'index',
      value: result.parameterIndex,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'bound',
      value: result.bound,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForFunctionType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesObjectNode.fromValue(
      name: 'returnType',
      value: result.returnType,
      isolateRef: isolateRef,
    ),
    if (result.typeParameters != null)
      ValuesObjectNode.fromValue(
        name: 'typeParameters',
        value: result.typeParameters,
        isolateRef: isolateRef,
      ),
    ValuesObjectNode.fromList(
      name: 'parameters',
      type: '_Parameters',
      list: result.parameters,
      displayNameBuilder: (e) => '_Parameter',
      childBuilder: (e) {
        final parameter = e as Parameter;
        return [
          if (parameter.name != null) ...[
            ValuesObjectNode.fromString(
              name: 'name',
              value: parameter.name,
              isolateRef: isolateRef,
            ),
            ValuesObjectNode.fromValue(
              name: 'required',
              value: parameter.required,
              isolateRef: isolateRef,
            ),
          ],
          ValuesObjectNode.fromValue(
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

List<ValuesObjectNode> createVariablesForType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesObjectNode.fromString(
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
      ValuesObjectNode.fromValue(
        name: 'typeArguments',
        value: result.typeArguments,
        isolateRef: isolateRef,
      ),
    if (result.targetType != null)
      ValuesObjectNode.fromValue(
        name: 'targetType',
        value: result.targetType,
        isolateRef: isolateRef,
      ),
  ];
}

List<ValuesObjectNode> createVariablesForReceivePort(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    if (result.debugName!.isNotEmpty)
      ValuesObjectNode.fromString(
        name: 'debugName',
        value: result.debugName,
        isolateRef: isolateRef,
      ),
    ValuesObjectNode.fromValue(
      name: 'portId',
      value: result.portId,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'allocationLocation',
      value: result.allocationLocation,
      isolateRef: isolateRef,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForClosure(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesObjectNode.fromValue(
      name: 'function',
      value: result.closureFunction,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
    ValuesObjectNode.fromValue(
      name: 'context',
      value: result.closureContext,
      isolateRef: isolateRef,
      artificialValue: result.closureContext != null,
    ),
  ];
}

List<ValuesObjectNode> createVariablesForRegExp(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    ValuesObjectNode.fromValue(
      name: 'pattern',
      value: result.pattern,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'isCaseSensitive',
      value: result.isCaseSensitive,
      isolateRef: isolateRef,
    ),
    ValuesObjectNode.fromValue(
      name: 'isMultiline',
      value: result.isMultiLine,
      isolateRef: isolateRef,
    ),
  ];
}

Future<ValuesObjectNode> _buildVariable(
  RemoteDiagnosticsNode diagnostic,
  ObjectGroupBase inspectorService,
  IsolateRef? isolateRef,
) async {
  final instanceRef =
      await inspectorService.toObservatoryInstanceRef(diagnostic.valueRef);
  return ValuesObjectNode.fromValue(
    name: diagnostic.name,
    value: instanceRef,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
  );
}

Future<List<ValuesObjectNode>> createVariablesForDiagnostics(
  ObjectGroupBase inspectorService,
  List<RemoteDiagnosticsNode> diagnostics,
  IsolateRef isolateRef,
) async {
  final variables = <Future<ValuesObjectNode>>[];
  for (var diagnostic in diagnostics) {
    // Omit hidden properties.
    if (diagnostic.level == DiagnosticLevel.hidden) continue;
    variables.add(_buildVariable(diagnostic, inspectorService, isolateRef));
  }
  return variables.isNotEmpty ? await Future.wait(variables) : const [];
}

List<ValuesObjectNode> createVariablesForAssociations(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <ValuesObjectNode>[];
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
        ValuesObjectNode.fromValue(
          name: association.key.valueAsString,
          value: association.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      final key = ValuesObjectNode.fromValue(
        name: '[key]',
        value: association.key,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final value = ValuesObjectNode.fromValue(
        name: '[value]',
        value: association.value,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final entryNum = instance.offset == null ? i : i + instance.offset!;
      variables.add(
        ValuesObjectNode.text('[Entry $entryNum]')
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
List<ValuesObjectNode> createVariablesForBytes(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final bytes = base64.decode(instance.bytes!);
  final variables = <ValuesObjectNode>[];
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
        return <ValuesObjectNode>[];
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
        return <ValuesObjectNode>[];
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
      ValuesObjectNode.fromValue(
        name: '[$name]',
        value: result[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<ValuesObjectNode> createVariablesForElements(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <ValuesObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final name = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      ValuesObjectNode.fromValue(
        name: '[$name]',
        value: elements[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<ValuesObjectNode> createVariablesForFields(
  Instance instance,
  IsolateRef? isolateRef, {
  Set<String>? existingNames,
}) {
  final variables = <ValuesObjectNode>[];
  for (var field in instance.fields!) {
    final name = field.decl?.name;
    if (name == null) {
      variables.add(
        ValuesObjectNode.fromValue(
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      if (existingNames != null && existingNames.contains(name)) continue;
      variables.add(
        ValuesObjectNode.fromValue(
          name: name,
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    }
  }
  return variables;
}
