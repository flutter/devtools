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

import '../screens/debugger/debugger_model.dart';
import '../screens/inspector/diagnostics_node.dart';
import '../screens/inspector/inspector_service.dart';
import 'config_specific/logger/logger.dart';
import 'globals.dart';
import 'primitives/trees.dart';
import 'primitives/utils.dart';

Future<void> addExpandableChildren(
  DartObjectNode variable,
  List<DartObjectNode> children, {
  bool expandAll = false,
}) async {
  final tasks = <Future>[];
  for (var child in children) {
    if (expandAll) {
      tasks.add(buildVariablesTree(child, expandAll: expandAll));
    }
    variable.addChild(child);
  }
  if (tasks.isNotEmpty) {
    await Future.wait(tasks);
  }
}

/// Builds the tree representation for a [DartObjectNode] object by querying
/// data, creating child [DartObjectNode] objects, and assigning parent-child
/// relationships.
///
/// We call this method as we expand variables in the variable tree, because
/// building the tree for all variable data at once is very expensive.
Future<void> buildVariablesTree(
  DartObjectNode variable, {
  bool expandAll = false,
}) async {
  final ref = variable.ref;
  if (!variable.isExpandable || variable.treeInitializeStarted || ref == null)
    return;
  variable.treeInitializeStarted = true;

  final isolateRef = ref.isolateRef;
  final instanceRef = ref.instanceRef;
  final diagnostic = ref.diagnostic;
  if (diagnostic != null && includeDiagnosticPropertiesInDebugger) {
    final service = diagnostic.inspectorService;
    Future<void> _addPropertiesHelper(
      List<RemoteDiagnosticsNode>? properties,
    ) async {
      if (properties == null || service == null || isolateRef == null) return;
      await addExpandableChildren(
        variable,
        await _createVariablesForDiagnostics(
          service,
          properties,
          isolateRef,
        ),
        expandAll: true,
      );
    }

    if (diagnostic.inlineProperties.isNotEmpty) {
      await _addPropertiesHelper(diagnostic.inlineProperties);
    } else {
      assert(!service!.disposed);
      if (!service!.disposed) {
        await _addPropertiesHelper(await diagnostic.getProperties(service));
      }
    }
  }
  final existingNames = <String>{};
  for (var child in variable.children) {
    final name = child.name;
    if (name != null && name.isNotEmpty) {
      existingNames.add(name);
      if (!isPrivate(name)) {
        // Assume private and public names with the same name reference the same
        // data so showing both is not useful.
        existingNames.add('_$name');
      }
    }
  }

  try {
    if (variable.childCount > DartObjectNode.MAX_CHILDREN_IN_GROUPING) {
      final numChildrenInGrouping =
          variable.childCount >= pow(DartObjectNode.MAX_CHILDREN_IN_GROUPING, 2)
              ? (roundToNearestPow10(variable.childCount) /
                      DartObjectNode.MAX_CHILDREN_IN_GROUPING)
                  .floor()
              : DartObjectNode.MAX_CHILDREN_IN_GROUPING;

      var start = variable.offset;
      final end = start + variable.childCount;
      while (start < end) {
        final count = min(end - start, numChildrenInGrouping);
        variable.addChild(
          DartObjectNode.grouping(variable.ref, offset: start, count: count),
        );
        start += count;
      }
    } else if (instanceRef != null && serviceManager.service != null) {
      final variableId = variable.ref!.isolateRef!.id!;
      final dynamic result = await serviceManager.service!.getObject(
        variableId,
        instanceRef.id!,
        offset: variable.offset,
        count: variable.childCount,
      );
      if (result is Instance) {
        switch (result.kind) {
          case InstanceKind.kMap:
            variable.addAllChildren(
              _createVariablesForAssociations(result, isolateRef),
            );
            break;
          case InstanceKind.kList:
            variable.addAllChildren(
              _createVariablesForElements(result, isolateRef),
            );
            break;
          case InstanceKind.kUint8ClampedList:
          case InstanceKind.kUint8List:
          case InstanceKind.kUint16List:
          case InstanceKind.kUint32List:
          case InstanceKind.kUint64List:
          case InstanceKind.kInt8List:
          case InstanceKind.kInt16List:
          case InstanceKind.kInt32List:
          case InstanceKind.kInt64List:
          case InstanceKind.kFloat32List:
          case InstanceKind.kFloat64List:
          case InstanceKind.kInt32x4List:
          case InstanceKind.kFloat32x4List:
          case InstanceKind.kFloat64x2List:
            variable.addAllChildren(
              _createVariablesForBytes(result, isolateRef),
            );
            break;
          case InstanceKind.kRegExp:
            variable.addAllChildren(
              _createVariablesForRegExp(result, isolateRef),
            );
            break;
          case InstanceKind.kClosure:
            variable.addAllChildren(
              _createVariablesForClosure(result, isolateRef),
            );
            break;
          case InstanceKind.kReceivePort:
            variable.addAllChildren(
              _createVariablesForReceivePort(result, isolateRef),
            );
            break;
          case InstanceKind.kType:
            variable.addAllChildren(
              _createVariablesForType(result, isolateRef),
            );
            break;
          case InstanceKind.kTypeParameter:
            variable.addAllChildren(
              _createVariablesForTypeParameters(result, isolateRef),
            );
            break;
          case InstanceKind.kFunctionType:
            variable.addAllChildren(
              _createVariablesForFunctionType(result, isolateRef),
            );
            break;
          case InstanceKind.kWeakProperty:
            variable.addAllChildren(
              _createVariablesForWeakProperty(result, isolateRef),
            );
            break;
          case InstanceKind.kStackTrace:
            variable.addAllChildren(
              _createVariablesForStackTrace(result, isolateRef),
            );
            break;
          default:
            break;
        }
        if (result.fields != null) {
          variable.addAllChildren(
            _createVariablesForFields(
              result,
              isolateRef,
              existingNames: existingNames,
            ),
          );
        }
      }
    } else if (variable.value != null) {
      var value = variable.value;
      if (value is ObjRef) {
        value = await serviceManager.service!.getObject(
          isolateRef!.id!,
          value.id!,
        );
        switch (value.runtimeType) {
          case Func:
            final function = value as Func;
            variable.addAllChildren(
              _createVariablesForFunc(function, isolateRef),
            );
            break;
          case Context:
            final context = value as Context;
            variable.addAllChildren(
              _createVariablesForContext(context, isolateRef),
            );
            break;
        }
      } else if (value is! String && value is! num && value is! bool) {
        switch (value.runtimeType) {
          case Parameter:
            final parameter = value as Parameter;
            variable.addAllChildren(
              _createVariablesForParameter(parameter, isolateRef),
            );
            break;
        }
      }
    }
  } on SentinelException {
    // Fail gracefully if calling `getObject` throws a SentinelException.
  }

  if (diagnostic != null && includeDiagnosticChildren) {
    // Always add children last after properties to avoid confusion.
    final ObjectGroupBase? service = diagnostic.inspectorService;
    final diagnosticChildren = await diagnostic.children;
    if (diagnosticChildren != null && diagnosticChildren.isNotEmpty) {
      final childrenNode = DartObjectNode.text(
        pluralize('child', diagnosticChildren.length, plural: 'children'),
      );
      variable.addChild(childrenNode);
      if (service != null && isolateRef != null) {
        await addExpandableChildren(
          childrenNode,
          await _createVariablesForDiagnostics(
            service,
            diagnosticChildren,
            isolateRef,
          ),
          expandAll: expandAll,
        );
      }
    }
  }
  final inspectorService = serviceManager.inspectorService;
  if (inspectorService != null) {
    final tasks = <Future>[];
    ObjectGroupBase? group;
    Future<void> _maybeUpdateRef(DartObjectNode child) async {
      final childRef = child.ref;
      if (childRef == null) return;
      if (childRef.diagnostic == null) {
        // TODO(jacobr): also check whether the InstanceRef is an instance of
        // Diagnosticable and show the Diagnosticable properties in that case.
        final instanceRef = childRef.instanceRef;
        // This is an approximation of eval('instanceRef is DiagnosticsNode')
        // TODO(jacobr): cache the full class hierarchy so we can cheaply check
        // instanceRef is DiagnosticsNode without having to do an eval.
        if (instanceRef != null &&
            (instanceRef.classRef?.name == 'DiagnosticableTreeNode' ||
                instanceRef.classRef?.name == 'DiagnosticsProperty')) {
          // The user is expecting to see the object the DiagnosticsNode is
          // describing not the DiagnosticsNode itself.
          try {
            group ??= inspectorService.createObjectGroup('temp');
            final valueInstanceRef = await group!.evalOnRef(
              'object.value',
              childRef,
            );
            // TODO(jacobr): add the Diagnostics properties as well?
            child._ref = GenericInstanceRef(
              isolateRef: isolateRef,
              value: valueInstanceRef,
            );
          } catch (e) {
            if (e is! SentinelException) {
              log(
                'Caught $e accessing the value of an object',
                LogLevel.warning,
              );
            }
          }
        }
      }
    }

    for (var child in variable.children) {
      tasks.add(_maybeUpdateRef(child));
    }
    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
      unawaited(group?.dispose());
    }
  }
  variable.treeInitializeComplete = true;
}

List<DartObjectNode> _createVariablesForStackTrace(
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
      )
  ];
}

List<DartObjectNode> _createVariablesForParameter(
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

List<DartObjectNode> _createVariablesForContext(
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

List<DartObjectNode> _createVariablesForFunc(
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

List<DartObjectNode> _createVariablesForWeakProperty(
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

List<DartObjectNode> _createVariablesForTypeParameters(
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

List<DartObjectNode> _createVariablesForFunctionType(
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
            )
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

List<DartObjectNode> _createVariablesForType(
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

List<DartObjectNode> _createVariablesForReceivePort(
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

List<DartObjectNode> _createVariablesForClosure(
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

List<DartObjectNode> _createVariablesForRegExp(
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
  ObjectGroupBase inspectorService,
  IsolateRef? isolateRef,
) async {
  final instanceRef =
      await inspectorService.toObservatoryInstanceRef(diagnostic.valueRef);
  return DartObjectNode.fromValue(
    name: diagnostic.name,
    value: instanceRef,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
  );
}

Future<List<DartObjectNode>> _createVariablesForDiagnostics(
  ObjectGroupBase inspectorService,
  List<RemoteDiagnosticsNode> diagnostics,
  IsolateRef isolateRef,
) async {
  final variables = <Future<DartObjectNode>>[];
  for (var diagnostic in diagnostics) {
    // Omit hidden properties.
    if (diagnostic.level == DiagnosticLevel.hidden) continue;
    variables.add(_buildVariable(diagnostic, inspectorService, isolateRef));
  }
  return variables.isNotEmpty ? await Future.wait(variables) : const [];
}

List<DartObjectNode> _createVariablesForAssociations(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
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
        DartObjectNode.fromValue(
          name: association.key.valueAsString,
          value: association.value,
          isolateRef: isolateRef,
        ),
      );
    } else {
      final key = DartObjectNode.fromValue(
        name: '[key]',
        value: association.key,
        isolateRef: isolateRef,
        artificialName: true,
      );
      final value = DartObjectNode.fromValue(
        name: '[value]',
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
List<DartObjectNode> _createVariablesForBytes(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final bytes = base64.decode(instance.bytes!);
  final variables = <DartObjectNode>[];
  List<dynamic> result;
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

List<DartObjectNode> _createVariablesForElements(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final name = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      DartObjectNode.fromValue(
        name: '[$name]',
        value: elements[i],
        isolateRef: isolateRef,
        artificialName: true,
      ),
    );
  }
  return variables;
}

List<DartObjectNode> _createVariablesForFields(
  Instance instance,
  IsolateRef? isolateRef, {
  Set<String>? existingNames,
}) {
  final variables = <DartObjectNode>[];
  for (var field in instance.fields!) {
    final name = field.decl!.name;
    if (existingNames != null && existingNames.contains(name)) continue;
    variables.add(
      DartObjectNode.fromValue(
        name: name,
        value: field.value,
        isolateRef: isolateRef,
      ),
    );
  }
  return variables;
}

// TODO(jacobr): gracefully handle cases where the isolate has closed and
// InstanceRef objects have become sentinels.
class DartObjectNode extends TreeNode<DartObjectNode> {
  DartObjectNode._({
    this.name,
    this.text,
    GenericInstanceRef? ref,
    int? offset,
    int? childCount,
    this.artificialName = false,
    this.artificialValue = false,
  })  : _ref = ref,
        _offset = offset,
        _childCount = childCount {
    indentChildren = ref?.diagnostic?.style != DiagnosticsTreeStyle.flat;
  }

  /// Creates a variable from a value that must be an VM service type or a
  /// primitive type.
  ///
  /// [value] should typically be an [InstanceRef] but can also be a [Sentinel]
  /// [ObjRef] or primitive type such as num or String.
  ///
  /// [artificialName] and [artificialValue] is used by [ExpandableVariable] to
  /// determine styling of `Text(name)` and `Text(displayValue)` respectively.
  /// Artificial names and values are rendered using `subtleFixedFontStyle` to
  /// put less emphasis on the name (e.g., for the root node of a JSON tree).
  factory DartObjectNode.fromValue({
    String? name,
    required Object? value,
    bool artificialName = false,
    bool artificialValue = false,
    RemoteDiagnosticsNode? diagnostic,
    required IsolateRef? isolateRef,
  }) {
    name = name ?? '';
    return DartObjectNode._(
      name: name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        diagnostic: diagnostic,
        value: value,
      ),
      artificialName: artificialName,
      artificialValue: artificialValue,
    );
  }

  /// Creates a variable from a `String` which displays [value] with quotation
  /// marks.
  factory DartObjectNode.fromString({
    String? name,
    required String? value,
    required IsolateRef? isolateRef,
  }) {
    name = name ?? '';
    return DartObjectNode._(
      name: name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: value != null ? "'$value'" : null,
      ),
    );
  }

  /// Creates a list node from a list of values that must be VM service objects
  /// or primitives.
  ///
  /// [list] should be a list of VM service objects or primitives.
  ///
  /// [displayNameBuilder] is used to transform a list element that will be the
  /// child node's `value`.
  ///
  /// [childBuilder] is used to generate nodes for each child.
  ///
  /// [artificialChildValues] determines styling of `Text(displayValue)` for
  /// child nodes. Artificial values are rendered using `subtleFixedFontStyle`
  /// to put less emphasis on the value.
  factory DartObjectNode.fromList({
    String? name,
    required String? type,
    required List<Object?>? list,
    required IsolateRef? isolateRef,
    Object? Function(Object?)? displayNameBuilder,
    List<DartObjectNode> Function(Object?)? childBuilder,
    bool artificialChildValues = true,
  }) {
    name = name ?? '';
    return DartObjectNode._(
      name: name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: '$type (${_itemCount(list?.length ?? 0)})',
      ),
      artificialValue: true,
      childCount: list?.length ?? 0,
    )..addAllChildren([
        if (list != null)
          for (int i = 0; i < list.length; ++i)
            DartObjectNode.fromValue(
              name: '[$i]',
              value: displayNameBuilder?.call(list[i]) ?? list[i],
              isolateRef: isolateRef,
              artificialName: true,
              artificialValue: artificialChildValues,
            )..addAllChildren([
                if (childBuilder != null) ...childBuilder(list[i]),
              ]),
      ]);
  }

  factory DartObjectNode.create(
    BoundVariable variable,
    IsolateRef? isolateRef,
  ) {
    final value = variable.value;
    return DartObjectNode._(
      name: variable.name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: value,
      ),
    );
  }

  factory DartObjectNode.text(String text) {
    return DartObjectNode._(
      text: text,
      artificialName: true,
    );
  }

  factory DartObjectNode.grouping(
    GenericInstanceRef? ref, {
    required int offset,
    required int count,
  }) {
    return DartObjectNode._(
      ref: ref,
      text: '[$offset - ${offset + count - 1}]',
      offset: offset,
      childCount: count,
    );
  }

  static const MAX_CHILDREN_IN_GROUPING = 100;

  final String? text;
  final String? name;

  /// [artificialName] is used by [ExpandableVariable] to determine styling of
  /// `Text(name)`. Artificial names are rendered using `subtleFixedFontStyle`
  /// to put less emphasis on the name (e.g., for the root node of a JSON tree).
  final bool artificialName;

  /// [artificialValue] is used by [ExpandableVariable] to determine styling of
  /// `Text(displayValue)`. Artificial names are rendered using
  /// `subtleFixedFontStyle` to put less emphasis on the value (e.g., for type
  /// names).
  final bool artificialValue;

  GenericInstanceRef? get ref => _ref;
  GenericInstanceRef? _ref;

  /// The point to fetch the variable from (in the case of large variables that
  /// we fetch only parts of at a time).
  int get offset => _offset ?? 0;

  int? _offset;

  int get childCount {
    if (_childCount != null) return _childCount!;

    final value = this.value;
    if (value is InstanceRef) {
      if (value.kind != null &&
          (value.kind!.endsWith('List') ||
              value.kind == InstanceKind.kList ||
              value.kind == InstanceKind.kMap)) {
        return value.length ?? 0;
      }
    }

    return 0;
  }

  int? _childCount;

  bool treeInitializeStarted = false;
  bool treeInitializeComplete = false;

  @override
  bool get isExpandable {
    if (treeInitializeComplete || children.isNotEmpty || childCount > 0) {
      return children.isNotEmpty || childCount > 0;
    }
    final diagnostic = ref?.diagnostic;
    if (diagnostic != null &&
        ((diagnostic.inlineProperties.isNotEmpty) || diagnostic.hasChildren))
      return true;
    // TODO(jacobr): do something smarter to avoid expandable variable flicker.
    final instanceRef = ref?.instanceRef;
    if (instanceRef != null) {
      if (instanceRef.kind == InstanceKind.kStackTrace) {
        return true;
      }
      return instanceRef.valueAsString == null;
    }
    return (ref?.value is! String?) &&
        (ref?.value is! num?) &&
        (ref?.value is! bool?);
  }

  Object? get value => ref?.value;

  // TODO(kenz): add custom display for lists with more than 100 elements
  String? get displayValue {
    if (text != null) {
      return text;
    }
    final value = this.value;

    String? valueStr;

    if (value == null) return null;

    if (value is InstanceRef) {
      final kind = value.kind;
      if (kind == InstanceKind.kStackTrace) {
        final depth = children.length;
        valueStr = 'StackTrace ($depth ${pluralize('frame', depth)})';
      } else if (value.valueAsString == null) {
        valueStr = value.classRef?.name ?? '';
      } else {
        valueStr = value.valueAsString ?? '';
        if (value.valueAsStringIsTruncated == true) {
          valueStr += '...';
        }
        if (kind == InstanceKind.kString) {
          // TODO(devoncarew): Handle multi-line strings.
          valueStr = "'$valueStr'";
        }
      }
      // List, Map, Uint8List, Uint16List, etc...
      if (kind != null && kind == InstanceKind.kList ||
          kind == InstanceKind.kMap ||
          kind!.endsWith('List')) {
        final itemLength = value.length;
        if (itemLength == null) return valueStr;
        return '$valueStr (${_itemCount(itemLength)})';
      }
    } else if (value is Sentinel) {
      valueStr = value.valueAsString;
    } else if (value is TypeArgumentsRef) {
      valueStr = value.name;
    } else if (value is ObjRef) {
      valueStr = _stripReferenceToken(value.type);
    } else {
      valueStr = value.toString();
    }

    return valueStr;
  }

  static String _itemCount(int count) {
    return '${nf.format(count)} ${pluralize('item', count)}';
  }

  static String _stripReferenceToken(String type) {
    if (type.startsWith('@')) {
      return '_${type.substring(1)}';
    }
    return '_$type';
  }

  @override
  String toString() {
    if (text != null) return text!;

    final instanceRef = ref!.instanceRef;
    final value =
        instanceRef is InstanceRef ? instanceRef.valueAsString : instanceRef;
    return '$name - $value';
  }

  /// Selects the object in the Flutter Widget inspector.
  ///
  /// Returns whether the inspector selection was changed
  Future<bool> inspectWidget() async {
    if (ref?.instanceRef == null) {
      return false;
    }
    final inspectorService = serviceManager.inspectorService;
    if (inspectorService == null) {
      return false;
    }
    // Group name doesn't matter in this case.
    final group = inspectorService.createObjectGroup('inspect-variables');
    if (group is ObjectGroup) {
      try {
        return await group.setSelection(ref!);
      } catch (e) {
        // This is somewhat unexpected. The inspectorRef must have been disposed.
        return false;
      } finally {
        // Not really needed as we shouldn't actually be allocating anything.
        unawaited(group.dispose());
      }
    }
    return false;
  }

  Future<bool> get isInspectable async {
    if (_isInspectable != null) return _isInspectable!;

    if (ref == null) return false;
    final inspectorService = serviceManager.inspectorService;
    if (inspectorService == null) {
      return false;
    }

    // Group name doesn't matter in this case.
    final group = inspectorService.createObjectGroup('inspect-variables');

    try {
      _isInspectable = await group.isInspectable(ref!);
    } catch (e) {
      _isInspectable = false;
      // This is somewhat unexpected. The inspectorRef must have been disposed.
    } finally {
      // Not really needed as we shouldn't actually be allocating anything.
      unawaited(group.dispose());
    }
    return _isInspectable ?? false;
  }

  bool? _isInspectable;

  @override
  DartObjectNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
