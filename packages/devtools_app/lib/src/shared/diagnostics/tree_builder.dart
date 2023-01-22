// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:vm_service/vm_service.dart';

import '../../screens/debugger/debugger_model.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../primitives/utils.dart';
import 'dart_object_node.dart';
import 'diagnostics_node.dart';
import 'generic_instance_reference.dart';
import 'inspector_service.dart';
import 'variable_factory.dart';

Future<void> _addExpandableChildren(
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
      await _addExpandableChildren(
        variable,
        await createVariablesForDiagnostics(
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
      final result = await serviceManager.service!.getObject(
        variableId,
        instanceRef.id!,
        offset: variable.offset,
        count: variable.childCount,
      );
      if (result is Instance) {
        variable.addChild(
          createVariableForReferences(instanceRef, isolateRef),
          index: 0,
        );
        switch (result.kind) {
          case InstanceKind.kMap:
            variable.addAllChildren(
              createVariablesForAssociations(result, isolateRef),
            );
            break;
          case InstanceKind.kList:
            variable.addAllChildren(
              createVariablesForElements(result, isolateRef),
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
              createVariablesForBytes(result, isolateRef),
            );
            break;
          case InstanceKind.kRegExp:
            variable.addAllChildren(
              createVariablesForRegExp(result, isolateRef),
            );
            break;
          case InstanceKind.kClosure:
            variable.addAllChildren(
              createVariablesForClosure(result, isolateRef),
            );
            break;
          case InstanceKind.kReceivePort:
            variable.addAllChildren(
              createVariablesForReceivePort(result, isolateRef),
            );
            break;
          case InstanceKind.kType:
            variable.addAllChildren(
              createVariablesForType(result, isolateRef),
            );
            break;
          case InstanceKind.kTypeParameter:
            variable.addAllChildren(
              createVariablesForTypeParameters(result, isolateRef),
            );
            break;
          case InstanceKind.kFunctionType:
            variable.addAllChildren(
              createVariablesForFunctionType(result, isolateRef),
            );
            break;
          case InstanceKind.kWeakProperty:
            variable.addAllChildren(
              createVariablesForWeakProperty(result, isolateRef),
            );
            break;
          case InstanceKind.kStackTrace:
            variable.addAllChildren(
              createVariablesForStackTrace(result, isolateRef),
            );
            break;
          default:
            break;
        }
        if (result.fields != null) {
          variable.addAllChildren(
            createVariablesForFields(
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
              createVariablesForFunc(function, isolateRef),
            );
            break;
          case Context:
            final context = value as Context;
            variable.addAllChildren(
              createVariablesForContext(context, isolateRef),
            );
            break;
        }
      } else if (value is! String && value is! num && value is! bool) {
        switch (value.runtimeType) {
          case Parameter:
            final parameter = value as Parameter;
            variable.addAllChildren(
              createVariablesForParameter(parameter, isolateRef),
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
        await _addExpandableChildren(
          childrenNode,
          await createVariablesForDiagnostics(
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
            child.ref = GenericInstanceRef(
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
