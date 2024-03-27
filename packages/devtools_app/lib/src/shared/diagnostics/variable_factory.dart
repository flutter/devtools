// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:vm_service/vm_service.dart';

import '../memory/heap_object.dart';
import '../vm_utils.dart';
import 'dart_object_node.dart';
import 'diagnostics_node.dart';
import 'object_group_api.dart';
import 'primitives/record_fields.dart';

List<DartObjectNode> createVariablesForStackTrace(
  Instance stackTrace,
  IsolateRef? isolateRef,
) {
  final trace = stack_trace.Trace.parse(stackTrace.valueAsString!);
  return [
    for (int i = 0; i < trace.frames.length; ++i)
      DartObjectNode.fromValue(
        name: '[$i]',
        value: trace.frames[i].toString(),
        isolateRef: isolateRef,
        artificialName: true,
        artificialValue: true,
      ),
  ];
}

List<DartObjectNode> createVariablesForParameter(
  Parameter parameter,
  IsolateRef? isolateRef,
) {
  return [
    if (parameter.name != null)
      DartObjectNode.fromString(
        name: 'name',
        value: parameter.name,
        isolateRef: isolateRef,
      ),
    DartObjectNode.fromValue(
      name: 'required',
      value: parameter.required ?? false,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'type',
      value: parameter.parameterType,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForContext(
  Context context,
  IsolateRef isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'length',
      value: context.length,
      isolateRef: isolateRef,
    ),
    if (context.parent != null)
      DartObjectNode.fromValue(
        name: 'parent',
        value: context.parent,
        isolateRef: isolateRef,
      ),
    DartObjectNode.fromList(
      name: 'variables',
      type: '_ContextElement',
      list: context.variables,
      displayNameBuilder: (Object? e) => (e as ContextElement).value,
      artificialChildValues: false,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForFunc(
  Func function,
  IsolateRef isolateRef,
) {
  return [
    DartObjectNode.fromString(
      name: 'name',
      value: function.name,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'signature',
      value: function.signature,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'owner',
      value: function.owner,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
  ];
}

List<DartObjectNode> createVariablesForWeakProperty(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'key',
      value: result.propertyKey,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'value',
      value: result.propertyValue,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForTypeParameters(
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
    DartObjectNode.fromValue(
      name: 'index',
      value: result.parameterIndex,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'bound',
      value: result.bound,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForFunctionType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'returnType',
      value: result.returnType,
      isolateRef: isolateRef,
    ),
    if (result.typeParameters != null)
      DartObjectNode.fromValue(
        name: 'typeParameters',
        value: result.typeParameters,
        isolateRef: isolateRef,
      ),
    DartObjectNode.fromList(
      name: 'parameters',
      type: '_Parameters',
      list: result.parameters,
      displayNameBuilder: (e) => '_Parameter',
      childBuilder: (e) {
        final parameter = e as Parameter;
        return [
          if (parameter.name != null) ...[
            DartObjectNode.fromString(
              name: 'name',
              value: parameter.name,
              isolateRef: isolateRef,
            ),
            DartObjectNode.fromValue(
              name: 'required',
              value: parameter.required,
              isolateRef: isolateRef,
            ),
          ],
          DartObjectNode.fromValue(
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

List<DartObjectNode> createVariablesForType(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromString(
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
      DartObjectNode.fromValue(
        name: 'typeArguments',
        value: result.typeArguments,
        isolateRef: isolateRef,
      ),
    if (result.targetType != null)
      DartObjectNode.fromValue(
        name: 'targetType',
        value: result.targetType,
        isolateRef: isolateRef,
      ),
  ];
}

List<DartObjectNode> createVariablesForReceivePort(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    if (result.debugName!.isNotEmpty)
      DartObjectNode.fromString(
        name: 'debugName',
        value: result.debugName,
        isolateRef: isolateRef,
      ),
    DartObjectNode.fromValue(
      name: 'portId',
      value: result.portId,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'allocationLocation',
      value: result.allocationLocation,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForClosure(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'function',
      value: result.closureFunction,
      isolateRef: isolateRef,
      artificialValue: true,
    ),
    DartObjectNode.fromValue(
      name: 'context',
      value: result.closureContext,
      isolateRef: isolateRef,
      artificialValue: result.closureContext != null,
    ),
  ];
}

List<DartObjectNode> createVariablesForRegExp(
  Instance result,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'pattern',
      value: result.pattern,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'isCaseSensitive',
      value: result.isCaseSensitive,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'isMultiline',
      value: result.isMultiLine,
      isolateRef: isolateRef,
    ),
  ];
}

Future<DartObjectNode> _buildVariable(
  RemoteDiagnosticsNode diagnostic,
  InspectorObjectGroupApi<RemoteDiagnosticsNode> objectGroup,
  IsolateRef? isolateRef,
) async {
  final instanceRef =
      await objectGroup.toObservatoryInstanceRef(diagnostic.valueRef);
  return DartObjectNode.fromValue(
    name: diagnostic.name,
    value: instanceRef,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
  );
}

Future<List<DartObjectNode>> createVariablesForDiagnostics(
  InspectorObjectGroupApi<RemoteDiagnosticsNode> objectGroupApi,
  List<RemoteDiagnosticsNode> diagnostics,
  IsolateRef isolateRef,
) async {
  final variables = <Future<DartObjectNode>>[];
  for (var diagnostic in diagnostics) {
    // Omit hidden properties.
    if (diagnostic.level == DiagnosticLevel.hidden) continue;
    variables.add(_buildVariable(diagnostic, objectGroupApi, isolateRef));
  }
  return variables.isNotEmpty ? await Future.wait(variables) : const [];
}

List<DartObjectNode> createVariablesForMap(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final associations = instance.associations ?? <MapAssociation>[];

  // If the key type for the provided associations is not primitive, we want to
  // allow for users to drill down into the key object's properties. If we're
  // only dealing with primative types as keys, we can render a flatter
  // representation.
  final hasPrimitiveKey = associations.fold<bool>(
    false,
    (p, e) => p || isPrimitiveInstanceKind((e.key as InstanceRef).kind),
  );
  for (var i = 0; i < associations.length; i++) {
    final association = associations[i];
    final associationKey = association.key;

    if (associationKey is! InstanceRef) {
      continue;
    }
    if (hasPrimitiveKey) {
      variables.add(
        DartObjectNode.fromValue(
          name: associationKey.valueAsString,
          value: association.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      final key = DartObjectNode.fromValue(
        name: '[key]',
        value: associationKey,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final value = DartObjectNode.fromValue(
        name: '[val]', // `val`, not `value`, to align keys and values visually
        value: association.value,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final entryNum = instance.offset == null ? i : i + instance.offset!;
      variables.add(
        DartObjectNode.text('[Entry $entryNum]')
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
List<DartObjectNode> createVariablesForBytes(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final bytes = base64.decode(instance.bytes!);
  final variables = <DartObjectNode>[];
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
        return <DartObjectNode>[];
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
        return <DartObjectNode>[];
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
      DartObjectNode.fromValue(
        name: '[$name]',
        value: result[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<DartObjectNode> createVariablesForSets(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final elements = instance.elements ?? [];
  return elements.map((element) {
    return DartObjectNode.fromValue(
      value: element,
      isolateRef: isolateRef,
    );
  }).toList();
}

List<DartObjectNode> createVariablesForList(
  Instance instance,
  IsolateRef? isolateRef,
  HeapObject? heapSelection,
) {
  final variables = <DartObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final index = instance.offset == null ? i : i + instance.offset!;
    final name = '[$index]';

    variables.add(
      DartObjectNode.fromValue(
        name: name,
        value: elements[i],
        isolateRef: isolateRef,
        artificialName: true,
        heapSelection: heapSelection,
      ),
    );
  }
  return variables;
}

List<DartObjectNode> createVariablesForInstanceSet(
  int offset,
  int childCount,
  List<ObjRef> instances,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final loopLimit = min(offset + childCount, instances.length);
  for (int i = offset; i < loopLimit; i++) {
    variables.add(
      DartObjectNode.fromValue(
        name: '[$i]',
        value: instances[i],
        isolateRef: isolateRef,
      ),
    );
  }
  return variables;
}

List<DartObjectNode> createVariablesForRecords(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final fields = RecordFields(instance.fields);

  return [
    // Always show positional fields before named fields:
    for (var i = 0; i < fields.positional.length; i++)
      DartObjectNode.fromValue(
        // Positional fields are designated by their getter syntax, eg $1, $2,
        // $3, etc:
        name: '\$${i + 1}',
        value: fields.positional[i].value,
        isolateRef: isolateRef,
      ),
    for (final field in fields.named)
      DartObjectNode.fromValue(
        name: field.name,
        value: field.value,
        isolateRef: isolateRef,
      ),
  ];
}

List<DartObjectNode> createVariablesForFields(
  Instance instance,
  IsolateRef? isolateRef, {
  Set<String>? existingNames,
}) {
  final result = <DartObjectNode>[];
  for (var field in instance.fields!) {
    final name = field.decl?.name;
    if (name == null) {
      result.add(
        DartObjectNode.fromValue(
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      if (existingNames != null && existingNames.contains(name)) continue;
      result.add(
        DartObjectNode.fromValue(
          name: name,
          value: field.value,
          isolateRef: isolateRef,
        ),
      );
    }
  }
  return result;
}

List<DartObjectNode> createVariablesForMirrorReference(
  Instance mirrorReference,
  IsolateRef? isolateRef,
) {
  final referent = mirrorReference.mirrorReferent! as ClassRef;
  return [
    DartObjectNode.fromValue(
      name: 'class',
      value: referent.name,
      isolateRef: isolateRef,
    ),
    DartObjectNode.fromValue(
      name: 'library',
      value: referent.library!.uri,
      isolateRef: isolateRef,
    ),
  ];
}

List<DartObjectNode> createVariablesForUserTag(
  Instance userTag,
  IsolateRef? isolateRef,
) {
  return [
    DartObjectNode.fromValue(
      name: 'label',
      value: userTag.label,
      isolateRef: isolateRef,
    ),
  ];
}
