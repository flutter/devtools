// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:vm_service/vm_service.dart';

import '../../screens/debugger/debugger_model.dart';
import '../config_specific/logger/logger.dart';
import '../feature_flags.dart';
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

Future<void> _addDiagnosticsIfNeeded(
  RemoteDiagnosticsNode? diagnostic,
  IsolateRef? isolateRef,
  DartObjectNode variable,
) async {
  if (diagnostic == null || !includeDiagnosticPropertiesInDebugger) return;

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

Future<void> _addDiagnosticChildrenIfNeeded(
  DartObjectNode variable,
  RemoteDiagnosticsNode? diagnostic,
  IsolateRef? isolateRef,
  bool expandAll,
) async {
  if (diagnostic == null || !includeDiagnosticChildren) return;

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

void _setupGrouping(DartObjectNode variable) {
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
}

void addChildReferences(
  DartObjectNode variable,
) async {
  assert(FeatureFlags.evalAndBrowse);
  final ref = variable.ref!;
  if (ref is! ObjectReferences) {
    throw StateError('Wrong type: ${ref.runtimeType}');
  }

  final refNodeType = ref.refNodeType;

  switch (refNodeType) {
    case RefNodeType.refRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'live',
          ObjectReferences.withType(ref, RefNodeType.liveRefRoot),
        ),
        DartObjectNode.references(
          'static',
          ObjectReferences.withType(ref, RefNodeType.staticRefRoot),
        ),
      ]);
      break;
    case RefNodeType.staticRefRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'inbound',
          ObjectReferences.withType(ref, RefNodeType.staticInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.withType(ref, RefNodeType.staticOutRefs),
        ),
      ]);

      break;
    case RefNodeType.staticInRefs:
      final children = ref.heapSelection!
          .references(ref.refNodeType.direction!)
          .map(
            (s) => DartObjectNode.references(
              s.object.heapClass.className,
              ObjectReferences(
                refNodeType: RefNodeType.staticInRefs,
                heapSelection: s,
              ),
            ),
          )
          .toList();
      variable.addAllChildren(children);
      break;
    case RefNodeType.staticOutRefs:
      final children = ref.heapSelection!
          .references(ref.refNodeType.direction!)
          .map(
            (s) => DartObjectNode.references(
              '${s.object.heapClass.className}, ${prettyPrintRetainedSize(
                s.object.retainedSize,
              )}',
              ObjectReferences(
                refNodeType: RefNodeType.staticOutRefs,
                heapSelection: s,
              ),
            ),
          )
          .toList();
      variable.addAllChildren(children);
      break;
    case RefNodeType.liveRefRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'inbound',
          ObjectReferences.withType(ref, RefNodeType.liveInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.withType(ref, RefNodeType.liveOutRefs),
        ),
      ]);

      break;
    case RefNodeType.liveInRefs:
      variable.addChild(
        DartObjectNode.references(
          // Temporary placeholder
          '<live inbound refs>',
          ObjectReferences.withType(ref, RefNodeType.liveInRefs),
        ),
      );
      break;
    case RefNodeType.liveOutRefs:
      final isolateRef = variable.ref!.isolateRef;
      final instance = await _getObject(
        isolateRef: isolateRef,
        value: ref.instanceRef!,
        variable: variable,
      );

      if (instance is Instance) {
        await _addChildrenToInstanceVariable(
          variable: variable,
          value: instance,
          asReferences: true,
          isolateRef: isolateRef,
        );
      }
      break;
  }
}

Future<void> _addInstanceRefItems(
  DartObjectNode variable,
  InstanceRef instanceRef,
  IsolateRef? isolateRef,
) async {
  final ref = variable.ref;
  assert(ref is! ObjectReferences);

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

  final result = await _getObject(
    variable: variable,
    isolateRef: variable.ref!.isolateRef,
    value: instanceRef,
  );
  if (result is Instance) {
    if (FeatureFlags.evalAndBrowse && ref?.heapSelection != null) {
      final ref = variable.ref!;
      variable.addChild(
        DartObjectNode.references(
          'references',
          ObjectReferences(
            refNodeType: RefNodeType.refRoot,
            value: ref.value,
            isolateRef: ref.isolateRef,
            heapSelection: ref.heapSelection,
          ),
        ),
        index: 0,
      );
    }
    await _addChildrenToInstanceVariable(
      variable: variable,
      value: result,
      isolateRef: isolateRef,
      existingNames: existingNames,
      asReferences: false,
    );
  }
}

/// Adds children to the variable.
///
/// If [asReferences] is true, shows them as references, otherwize as field values.
Future<void> _addChildrenToInstanceVariable({
  required DartObjectNode variable,
  required Instance value,
  required bool asReferences,
  required IsolateRef? isolateRef,
  Set<String>? existingNames,
}) async {
  switch (value.kind) {
    case InstanceKind.kMap:
      variable.addAllChildren(
        createVariablesForAssociations(value, isolateRef),
      );
      break;
    case InstanceKind.kList:
      variable.addAllChildren(
        createVariablesForElements(value, isolateRef),
      );
      break;
    case InstanceKind.kRecord:
      variable.addAllChildren(
        createVariablesForRecords(value, isolateRef),
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
        createVariablesForBytes(value, isolateRef),
      );
      break;
    case InstanceKind.kRegExp:
      variable.addAllChildren(
        createVariablesForRegExp(value, isolateRef),
      );
      break;
    case InstanceKind.kClosure:
      variable.addAllChildren(
        createVariablesForClosure(value, isolateRef),
      );
      break;
    case InstanceKind.kReceivePort:
      variable.addAllChildren(
        createVariablesForReceivePort(value, isolateRef),
      );
      break;
    case InstanceKind.kType:
      variable.addAllChildren(
        createVariablesForType(value, isolateRef),
      );
      break;
    case InstanceKind.kTypeParameter:
      variable.addAllChildren(
        createVariablesForTypeParameters(value, isolateRef),
      );
      break;
    case InstanceKind.kFunctionType:
      variable.addAllChildren(
        createVariablesForFunctionType(value, isolateRef),
      );
      break;
    case InstanceKind.kWeakProperty:
      variable.addAllChildren(
        createVariablesForWeakProperty(value, isolateRef),
      );
      break;
    case InstanceKind.kStackTrace:
      variable.addAllChildren(
        createVariablesForStackTrace(value, isolateRef),
      );
      break;
    default:
      break;
  }
  if (value.fields != null && value.kind != InstanceKind.kRecord) {
    variable.addAllChildren(
      createVariablesForFields(
        value,
        isolateRef,
        existingNames: existingNames,
        asReferences: asReferences,
      ),
    );
  }
}

Future<Object?> _getObject({
  required IsolateRef? isolateRef,
  required ObjRef value,
  DartObjectNode? variable,
}) async {
  return await serviceManager.service!.getObject(
    isolateRef!.id!,
    value.id!,
    offset: variable?.offset,
    count: variable?.childCount,
  );
}

Future<void> _addValueItems(
  DartObjectNode variable,
  IsolateRef? isolateRef,
  Object? value,
) async {
  if (value is ObjRef) {
    value = await _getObject(isolateRef: isolateRef!, value: value);
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

Future<void> _addInspectorItems(variable, IsolateRef? isolateRef) async {
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

  await _addDiagnosticsIfNeeded(
    diagnostic,
    isolateRef,
    variable,
  );

  try {
    if (variable.childCount > DartObjectNode.MAX_CHILDREN_IN_GROUPING) {
      _setupGrouping(variable);
    } else if (ref is ObjectReferences) {
      addChildReferences(variable);
    } else if (instanceRef != null && serviceManager.service != null) {
      await _addInstanceRefItems(variable, instanceRef, isolateRef);
    } else if (variable.value != null) {
      final value = variable.value;
      await _addValueItems(variable, isolateRef, value);
    }
  } on SentinelException {
    // Fail gracefully if calling `getObject` throws a SentinelException.
  }

  await _addDiagnosticChildrenIfNeeded(
    variable,
    diagnostic,
    isolateRef,
    expandAll,
  );

  await _addInspectorItems(
    variable,
    isolateRef,
  );

  variable.treeInitializeComplete = true;
}
