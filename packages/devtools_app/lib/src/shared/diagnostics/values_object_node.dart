// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/debugger/debugger_model.dart';
import '../config_specific/logger/logger.dart';
import '../feature_flags.dart';
import '../globals.dart';
import '../primitives/utils.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';
import 'primitives/object_node.dart';
import 'variable_factory.dart';

Future<void> _addExpandableChildren(
  ValuesObjectNode variable,
  List<ValuesObjectNode> children, {
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

/// Builds the tree representation for a [ValuesObjectNode] object by querying
/// data, creating child [ValuesObjectNode] objects, and assigning parent-child
/// relationships.
///
/// We call this method as we expand variables in the variable tree, because
/// building the tree for all variable data at once is very expensive.
Future<void> buildVariablesTree(
  ValuesObjectNode variable, {
  bool expandAll = false,
}) async {
  final ref = variable.ref;
  if (!variable.isExpandable || variable.treeInitializeStarted || ref == null)
    return;
  variable.treeInitializeStarted = true;

  final isolateRef = ref.isolateRef;
  final instanceRef = ref.instanceRef;
  final diagnostic = ref.diagnostic;

  Obj? object;
  if (instanceRef != null && serviceManager.service != null) {
    final variableId = variable.ref!.isolateRef!.id!;
    object = await serviceManager.service!.getObject(
      variableId,
      instanceRef.id!,
      offset: variable.offset,
      count: variable.childCount,
    );
  }

  if (object is Instance && FeatureFlags.evalAndBrowse) {
    variable.addChild(createVariableForReferences(object, isolateRef));
  }

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
    final name = child is ValuesObjectNode ? child.name : null;
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
    if (variable.childCount > ValuesObjectNode.MAX_CHILDREN_IN_GROUPING) {
      final numChildrenInGrouping = variable.childCount >=
              pow(ValuesObjectNode.MAX_CHILDREN_IN_GROUPING, 2)
          ? (roundToNearestPow10(variable.childCount) /
                  ValuesObjectNode.MAX_CHILDREN_IN_GROUPING)
              .floor()
          : ValuesObjectNode.MAX_CHILDREN_IN_GROUPING;

      var start = variable.offset;
      final end = start + variable.childCount;
      while (start < end) {
        final count = min(end - start, numChildrenInGrouping);
        variable.addChild(
          ValuesObjectNode.grouping(variable.ref, offset: start, count: count),
        );
        start += count;
      }
    } else if (object != null) {
      if (object is Instance) {
        switch (object.kind) {
          case InstanceKind.kMap:
            variable.addAllChildren(
              createVariablesForAssociations(object, isolateRef),
            );
            break;
          case InstanceKind.kList:
            variable.addAllChildren(
              createVariablesForElements(object, isolateRef),
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
              createVariablesForBytes(object, isolateRef),
            );
            break;
          case InstanceKind.kRegExp:
            variable.addAllChildren(
              createVariablesForRegExp(object, isolateRef),
            );
            break;
          case InstanceKind.kClosure:
            variable.addAllChildren(
              createVariablesForClosure(object, isolateRef),
            );
            break;
          case InstanceKind.kReceivePort:
            variable.addAllChildren(
              createVariablesForReceivePort(object, isolateRef),
            );
            break;
          case InstanceKind.kType:
            variable.addAllChildren(
              createVariablesForType(object, isolateRef),
            );
            break;
          case InstanceKind.kTypeParameter:
            variable.addAllChildren(
              createVariablesForTypeParameters(object, isolateRef),
            );
            break;
          case InstanceKind.kFunctionType:
            variable.addAllChildren(
              createVariablesForFunctionType(object, isolateRef),
            );
            break;
          case InstanceKind.kWeakProperty:
            variable.addAllChildren(
              createVariablesForWeakProperty(object, isolateRef),
            );
            break;
          case InstanceKind.kStackTrace:
            variable.addAllChildren(
              createVariablesForStackTrace(object, isolateRef),
            );
            break;
          default:
            break;
        }
        if (object.fields != null) {
          variable.addAllChildren(
            createVariablesForFields(
              object,
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
      final childrenNode = ValuesObjectNode.text(
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
    Future<void> _maybeUpdateRef(ObjectNode child) async {
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

// TODO(jacobr): gracefully handle cases where the isolate has closed and
// InstanceRef objects have become sentinels.
class ValuesObjectNode extends ObjectNode {
  ValuesObjectNode._({
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
  factory ValuesObjectNode.fromValue({
    String? name,
    required Object? value,
    bool artificialName = false,
    bool artificialValue = false,
    RemoteDiagnosticsNode? diagnostic,
    required IsolateRef? isolateRef,
  }) {
    name = name ?? '';
    return ValuesObjectNode._(
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
  factory ValuesObjectNode.fromString({
    String? name,
    required String? value,
    required IsolateRef? isolateRef,
  }) {
    name = name ?? '';
    return ValuesObjectNode._(
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
  factory ValuesObjectNode.fromList({
    String? name,
    required String? type,
    required List<Object?>? list,
    required IsolateRef? isolateRef,
    Object? Function(Object?)? displayNameBuilder,
    List<ValuesObjectNode> Function(Object?)? childBuilder,
    bool artificialChildValues = true,
  }) {
    name = name ?? '';
    return ValuesObjectNode._(
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
            ValuesObjectNode.fromValue(
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

  factory ValuesObjectNode.create(
    BoundVariable variable,
    IsolateRef? isolateRef,
  ) {
    final value = variable.value;
    return ValuesObjectNode._(
      name: variable.name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: value,
      ),
    );
  }

  factory ValuesObjectNode.text(String text) {
    return ValuesObjectNode._(
      text: text,
      artificialName: true,
    );
  }

  factory ValuesObjectNode.grouping(
    GenericInstanceRef? ref, {
    required int offset,
    required int count,
  }) {
    return ValuesObjectNode._(
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

  @override
  GenericInstanceRef? get ref => _ref;
  GenericInstanceRef? _ref;

  /// The point to fetch the variable from (in the case of large variables that
  /// we fetch only parts of at a time).
  int get offset => _offset ?? 0;

  int? _offset;

  @override
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
    final value = ref?.value;
    return (value is! String?) && (value is! num?) && (value is! bool?);
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
      } else if (kind == 'Record') {
        // TODO(elliette): Compare against InstanceKind.kRecord when vm_service >= 10.0.0.
        valueStr = 'Record';
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
  @override
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

  @override
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
  ValuesObjectNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
