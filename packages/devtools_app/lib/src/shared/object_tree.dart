// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../screens/debugger/debugger_model.dart';
import '../screens/inspector/diagnostics_node.dart';
import '../screens/inspector/inspector_service.dart';
import 'globals.dart';

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
    try {
      final dynamic result =
          await _getObjectWithRetry(instanceRef.id!, variable);
      if (result is Instance) {
        if (result.associations != null) {
          variable.addAllChildren(
            _createVariablesForAssociations(result, isolateRef),
          );
        } else if (result.elements != null) {
          variable
              .addAllChildren(_createVariablesForElements(result, isolateRef));
        } else if (result.bytes != null) {
          variable.addAllChildren(_createVariablesForBytes(result, isolateRef));
          // Check fields last, as all instanceRefs may have a non-null fields
          // with no entries.
        } else if (result.fields != null) {
          variable.addAllChildren(
            _createVariablesForFields(
              result,
              isolateRef,
              existingNames: existingNames,
            ),
          );
        }
      }
    } on SentinelException {
      // Fail gracefully if calling `getObject` throws a SentinelException.
    }
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

// TODO(elliette): Remove once the fix for dart-lang/webdev/issues/1439
// is landed. This works around a bug in DWDS where an error is thrown if
// `getObject` is called with offset/count for an object that has no length.
Future<Obj> _getObjectWithRetry(
  String objectId,
  DartObjectNode variable,
) async {
  final variableId = variable.ref!.isolateRef!.id!;
  try {
    final dynamic result = await serviceManager.service!.getObject(
      variableId,
      objectId,
      offset: variable.offset,
      count: variable.childCount,
    );
    return result;
  } catch (e) {
    final dynamic result =
        await serviceManager.service!.getObject(variableId, objectId);
    return result;
  }
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
  if (variables.isNotEmpty) {
    return await Future.wait(variables);
  } else {
    return const [];
  }
}

List<DartObjectNode> _createVariablesForAssociations(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final associations = instance.associations ?? [];
  for (var i = 0; i < associations.length; i++) {
    final association = associations[i];
    if (association.key is! InstanceRef) {
      continue;
    }
    variables.add(
      DartObjectNode.fromValue(
        name: association.key.valueAsString,
        value: association.value,
        isolateRef: isolateRef,
      ),
    );
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
  })  : _ref = ref,
        _offset = offset,
        _childCount = childCount {
    indentChildren = ref?.diagnostic?.style != DiagnosticsTreeStyle.flat;
  }

  /// Creates a variable from a value that must be an InstanceRef or a primitive
  /// type.
  ///
  /// [value] should typically be an [InstanceRef] but can also be a [Sentinel]
  /// [ObjRef] or primitive type such as num or String.
  ///
  /// [artificialName] is used by [ExpandableVariable] to determine styling of
  /// `Text(name)`. Artificial names are rendered using `subtleFixedFontStyle`
  /// to put less emphasis on the name (e.g., for the root node of a JSON tree).
  factory DartObjectNode.fromValue({
    String? name,
    required Object? value,
    bool artificialName = false,
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
    );
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
    return DartObjectNode._(text: text);
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
    return instanceRef != null ? instanceRef.valueAsString == null : false;
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
      if (value.valueAsString == null) {
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
    } else {
      valueStr = value.toString();
    }

    return valueStr;
  }

  String _itemCount(int count) {
    return '${nf.format(count)} ${pluralize('item', count)}';
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
