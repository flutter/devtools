// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/logger.dart';
import '../../primitives/trees.dart';
import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import '../../ui/search.dart';
import '../inspector/diagnostics_node.dart';
import '../inspector/inspector_service.dart';

/// Whether to include properties surfaced through Diagnosticable objects as
/// part of the generic Debugger view of an object.
bool includeDiagnosticPropertiesInDebugger = true;

/// Whether to include children surfaced through Diagnosticable objects as part
/// of the generic Debugger view of an object.
///
/// It is safer to set to false as it is hard to avoid confusing overlap between
/// the children visible under fields for typical objects and we don't have a
/// way of clarifying that these are children from the Diagnostic view of the
/// object which might be different from children on fields for the Inspector
/// summary tree case which has a filtered view of children.
bool includeDiagnosticChildren = false;

/// A generic [InstanceRef] using either format used by the [InspectorService]
/// or Dart VM.
///
/// Either one or both of [value] and [diagnostic] may be provided. The
/// `valueRef` getter on the [diagnostic] should refer to the same object as
/// [instanceRef] although using the [InspectorInstanceRef] scheme.
/// A [RemoteDiagnosticsNode] is used rather than an [InspectorInstanceRef] as
/// the additional data provided by [RemoteDiagnosticsNode] is helpful to
/// correctly display the object and [RemoteDiagnosticsNode] includes a
/// reference to an [InspectorInstanceRef]. [value] must be an ObjectRef,
/// Sentinel, or primitive type.
class GenericInstanceRef {
  GenericInstanceRef({
    required this.isolateRef,
    this.value,
    this.diagnostic,
  }) : assert(value == null ||
            value is ObjRef ||
            value is Sentinel ||
            value is num ||
            value is String ||
            value is bool ||
            value is Int32x4 ||
            value is Float32x4 ||
            value is Float64x2);

  final Object? value;

  InstanceRef? get instanceRef => value is InstanceRef ? value as InstanceRef : null;

  /// If both [diagnostic] and [instanceRef] are provided, [diagnostic.valueRef]
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode? diagnostic;

  final IsolateRef isolateRef;
}

/// A tuple of a script and an optional location.
class ScriptLocation {
  ScriptLocation(
    this.scriptRef, {
    this.location,
  }) : assert(scriptRef != null);

  final ScriptRef? scriptRef;

  /// This field can be null.
  final SourcePosition? location;

  @override
  bool operator ==(other) {
    return other is ScriptLocation &&
        other.scriptRef == scriptRef &&
        other.location == location;
  }

  @override
  int get hashCode => hashValues(scriptRef, location);

  @override
  String toString() => '${scriptRef!.uri} $location';
}

class SourcePosition {
  const SourcePosition({
    required this.line,
    required this.column,
    this.file,
    this.tokenPos,
  });

  static SourcePosition? calculatePosition(Script script, int tokenPos) {
    if (script.tokenPosTable == null) {
      return null;
    }

    return SourcePosition(
      line: script.getLineNumberFromTokenPos(tokenPos)!,
      column: script.getColumnNumberFromTokenPos(tokenPos)!,
      tokenPos: tokenPos,
    );
  }

  final String? file;
  final int line;
  final int column;
  final int? tokenPos;

  @override
  bool operator ==(other) {
    return other is SourcePosition &&
        other.line == line &&
        other.column == column &&
        other.tokenPos == tokenPos;
  }

  @override
  int get hashCode => (line << 7) ^ column;

  @override
  String toString() => '$line:$column';
}

class SourceToken with DataSearchStateMixin {
  SourceToken({required this.position, required this.length});

  final SourcePosition position;

  final int length;

  @override
  String toString() {
    return '$position-${position.column + length}';
  }
}

/// A tuple of a breakpoint and a source position.
abstract class BreakpointAndSourcePosition
    implements Comparable<BreakpointAndSourcePosition> {
  BreakpointAndSourcePosition._(this.breakpoint, [this.sourcePosition]);

  factory BreakpointAndSourcePosition.create(Breakpoint breakpoint,
      [SourcePosition? sourcePosition]) {
    if (breakpoint.location is SourceLocation) {
      return _BreakpointAndSourcePositionResolved(
          breakpoint, sourcePosition!, breakpoint.location as SourceLocation);
    } else if (breakpoint.location is UnresolvedSourceLocation) {
      return _BreakpointAndSourcePositionUnresolved(breakpoint, sourcePosition!,
          breakpoint.location as UnresolvedSourceLocation);
    } else {
      throw 'invalid value for breakpoint.location';
    }
  }

  final Breakpoint? breakpoint;
  final SourcePosition? sourcePosition;

  bool get resolved => breakpoint!.resolved!;

  ScriptRef get scriptRef;

  String get scriptUri;

  int get line;

  int get column;

  int get tokenPos;

  String get id => breakpoint!.id!;

  @override
  int get hashCode => breakpoint.hashCode;

  @override
  bool operator ==(other) {
    return other is BreakpointAndSourcePosition &&
        other.breakpoint == breakpoint;
  }

  @override
  int compareTo(BreakpointAndSourcePosition other) {
    final result = scriptUri.compareTo(other.scriptUri);
    if (result != 0) return result;

    if (resolved != other.resolved) return resolved ? 1 : -1;

    if (resolved) {
      return tokenPos - other.tokenPos;
    } else {
      return line - other.line;
    }
  }
}

class _BreakpointAndSourcePositionResolved extends BreakpointAndSourcePosition {
  _BreakpointAndSourcePositionResolved(
      Breakpoint breakpoint, SourcePosition sourcePosition, this.location)
      : super._(breakpoint, sourcePosition);

  final SourceLocation location;

  @override
  ScriptRef get scriptRef => location.script!;

  @override
  String get scriptUri => location.script!.uri!;

  @override
  int get tokenPos => location.tokenPos!;

  @override
  int get line => sourcePosition!.line;

  @override
  int get column => sourcePosition!.column;
}

class _BreakpointAndSourcePositionUnresolved
    extends BreakpointAndSourcePosition {
  _BreakpointAndSourcePositionUnresolved(
    Breakpoint breakpoint,
    SourcePosition? sourcePosition,
    this.location,
  ) : super._(breakpoint, sourcePosition);

  final UnresolvedSourceLocation location;

  @override
  ScriptRef get scriptRef => location.script!;

  @override
  String get scriptUri => location.script?.uri ?? location.scriptUri!;

  @override
  int get tokenPos => location.tokenPos!;

  @override
  int get line {

    if(sourcePosition != null && sourcePosition!.line != null) {
      return sourcePosition!.line;
    }

    return location.line!;
  }

  @override
  int get column {

    if(sourcePosition != null && sourcePosition!.column != null) {

      return sourcePosition!.column;
    }

    return location.column!;
  }
}

/// A tuple of a stack frame and a source position.
class StackFrameAndSourcePosition {
  StackFrameAndSourcePosition(
    this.frame, {
    this.position,
  });

  final Frame? frame;

  /// This can be null.
  final SourcePosition? position;

  ScriptRef? get scriptRef => frame!.location?.script;

  String? get scriptUri => frame!.location?.script?.uri;

  int? get line => position!.line;

  int? get column => position!.column;

  String get callStackDisplay {
    final asyncMarker = frame!.kind == FrameKind.kAsyncSuspensionMarker;
    return '$description${asyncMarker ? null : ' ($location)'}';
  }

  String get description {
    const unoptimized = '[Unoptimized] ';
    const none = '<none>';
    const anonymousClosure = '<anonymous closure>';
    const closure = '<closure>';
    const asyncBreak = '<async break>';

    if (frame!.kind == FrameKind.kAsyncSuspensionMarker) {
      return asyncBreak;
    }

    var name = frame!.code?.name ?? none;
    if (name.startsWith(unoptimized)) {
      name = name.substring(unoptimized.length);
    }
    name = name.replaceAll(anonymousClosure, closure);
    name = name == none ? name : '$name';
    return name;
  }

  String get location {
    final uri = scriptUri;
    if (uri == null) {
      return uri!;
    }
    final file = uri.split('/').last;
    return line == null ? file : '$file:$line';
  }
}

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
        List<RemoteDiagnosticsNode> properties) async {
      if (properties == null) return;
      await addExpandableChildren(
        variable,
        await _createVariablesForDiagnostics(
          service!,
          properties,
          isolateRef,
        ),
        expandAll: true,
      );
    }

    if (diagnostic.inlineProperties.isNotEmpty ?? false) {
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

    var start = variable.offset ?? 0;
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
              _createVariablesForAssociations(result, isolateRef));
        } else if (result.elements != null) {
          variable
              .addAllChildren(_createVariablesForElements(result, isolateRef));
        } else if (result.bytes != null) {
          variable.addAllChildren(_createVariablesForBytes(result, isolateRef));
          // Check fields last, as all instanceRefs may have a non-null fields
          // with no entries.
        } else if (result.fields != null) {
          variable.addAllChildren(_createVariablesForFields(result, isolateRef,
              existingNames: existingNames));
        }
      }
    } on SentinelException {
      // Fail gracefully if calling `getObject` throws a SentinelException.
    }
  }
  if (diagnostic != null && includeDiagnosticChildren) {
    // Always add children last after properties to avoid confusion.
    final ObjectGroupBase service = diagnostic.inspectorService!;
    final diagnosticChildren = await diagnostic.children;
    if (diagnosticChildren?.isNotEmpty ?? false) {
      final childrenNode = DartObjectNode.text(
        pluralize('child', diagnosticChildren!.length, plural: 'children'),
      );
      variable.addChild(childrenNode);

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
  final inspectorService = serviceManager.inspectorService;
  if (inspectorService != null) {
    final tasks = <Future>[];
    late ObjectGroupBase group;
    Future<void> _maybeUpdateRef(DartObjectNode child) async {
      if (child.ref == null) return;
      if (child.ref.diagnostic == null) {
        // TODO(jacobr): also check whether the InstanceRef is an instance of
        // Diagnosticable and show the Diagnosticable properties in that case.
        final instanceRef = child.ref.instanceRef;
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
            final valueInstanceRef = await group.evalOnRef(
              'object.value',
              child.ref,
            );
            // TODO(jacobr): add the Diagnostics properties as well?
            child._ref = GenericInstanceRef(
              isolateRef: isolateRef,
              value: valueInstanceRef!,
            );
          } catch (e) {
            if (e is! SentinelException) {
              log('Caught $e accessing the value of an object',
                  LogLevel.warning);
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
      unawaited(group.dispose());
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
  try {
    final dynamic result = await serviceManager.service!.getObject(
        variable.ref.isolateRef.id!, objectId,
        offset: variable.offset, count: variable.childCount);
    return result;
  } catch (e) {
    final dynamic result = await serviceManager.service
        ?.getObject(variable.ref.isolateRef.id!, objectId);
    return result;
  }
}

Future<DartObjectNode> _buildVariable(
  RemoteDiagnosticsNode diagnostic,
  ObjectGroupBase inspectorService,
  IsolateRef isolateRef,
) async {
  final instanceRef =
      await inspectorService.toObservatoryInstanceRef(diagnostic.valueRef);
  return DartObjectNode.fromValue(
    name: diagnostic.name!,
    value: instanceRef!,
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
  IsolateRef isolateRef,
) {
  final variables = <DartObjectNode>[];
  for (var i = 0; i < instance.associations!.length; i++) {
    final association = instance.associations![i];
    if (association.key is! InstanceRef) {
      continue;
    }
    final key = DartObjectNode.fromValue(
      name: '[key]',
      value: association.key,
      isolateRef: isolateRef,
    );
    final value = DartObjectNode.fromValue(
      name: '[value]',
      value: association.value,
      isolateRef: isolateRef,
    );
    final entryNum = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      DartObjectNode.text('[Entry $entryNum]')
        ..addChild(key)
        ..addChild(value),
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
  IsolateRef isolateRef,
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
      ),
    );
  }
  return variables;
}

List<DartObjectNode> _createVariablesForElements(
  Instance instance,
  IsolateRef isolateRef,
) {
  final variables = <DartObjectNode>[];
  for (int i = 0; i < instance.elements!.length; i++) {
    final name = instance.offset == null ? i : i + instance.offset!;
    variables.add(
      DartObjectNode.fromValue(
        name: '[$name]',
        value: instance.elements![i],
        isolateRef: isolateRef,
      ),
    );
  }
  return variables;
}

List<DartObjectNode> _createVariablesForFields(
  Instance instance,
  IsolateRef isolateRef, {
  Set<String>? existingNames,
}) {
  final variables = <DartObjectNode>[];
  for (var field in instance.fields!) {
    final name = field.decl!.name;
    if (existingNames != null && existingNames.contains(name)) continue;
    variables.add(
      DartObjectNode.fromValue(
        name: name!,
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
    required this.name,
    required this.text,
    GenericInstanceRef? ref,
    int? offset,
    int? childCount,
  })  : _ref = ref!,
        _offset = offset!,
        _isInspectable = false,
        _childCount = childCount! {
    indentChildren = ref.diagnostic!.style != DiagnosticsTreeStyle.flat;
  }

  /// Creates a variable from a value that must be an InstanceRef or a primitive
  /// type.
  ///
  /// [value] should typically be an [InstanceRef] but can also be a [Sentinel]
  /// [ObjRef] or primitive type such as num or String.
  factory DartObjectNode.fromValue({
    String name = '',
    required Object value,
    RemoteDiagnosticsNode? diagnostic,
    required IsolateRef isolateRef,
  }) {
    return DartObjectNode._(
      name: name,
      text: '',
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        diagnostic: diagnostic!,
        value: value,
      ),
    );
  }

  factory DartObjectNode.create(
    BoundVariable variable,
    IsolateRef isolateRef,
  ) {
    final value = variable.value;
    return DartObjectNode._(
      name: variable.name!,
      text: '',
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: value,
      ),
    );
  }

  factory DartObjectNode.text(String text) {
    return DartObjectNode._(text: text, name: '');
  }

  factory DartObjectNode.grouping(
    GenericInstanceRef ref, {
    required int offset,
    required int count,
  }) {
    return DartObjectNode._(
      ref: ref,
      name: '',
      text: '[$offset - ${offset + count - 1}]',
      offset: offset,
      childCount: count,
    );
  }

  static const MAX_CHILDREN_IN_GROUPING = 100;

  final String text;
  final String name;
  GenericInstanceRef get ref => _ref;
  GenericInstanceRef _ref;

  /// The point to fetch the variable from (in the case of large variables that
  /// we fetch only parts of at a time).
  int get offset => _offset ?? 0;

  int _offset;

  int get childCount {
    if (_childCount != null) return _childCount;

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

  int _childCount;

  bool treeInitializeStarted = false;
  bool treeInitializeComplete = false;

  @override
  bool get isExpandable {
    if (treeInitializeComplete || children.isNotEmpty || childCount > 0) {
      return children.isNotEmpty || childCount > 0;
    }
    final diagnostic = ref.diagnostic;
    if (diagnostic != null &&
        ((diagnostic.inlineProperties.isNotEmpty ?? false) ||
            diagnostic.hasChildren)) return true;
    // TODO(jacobr): do something smarter to avoid expandable variable flicker.
    final instanceRef = ref.instanceRef;
    return instanceRef != null ? instanceRef.valueAsString == null : false;
  }

  Object get value => ref.value!;

  // TODO(kenz): add custom display for lists with more than 100 elements
  String? get displayValue {
    if (text != null) {
      return text;
    }

    final Object value = this.value;

    String valueStr;

    if (value is InstanceRef) {
      if (value.valueAsString == null) {
        valueStr = value.classRef!.name!;
      } else {
        valueStr = value.valueAsString!;
        if (value.valueAsStringIsTruncated == true) {
          valueStr += '...';
        }
        if (value.kind == InstanceKind.kString) {
          // TODO(devoncarew): Handle multi-line strings.
          valueStr = "'$valueStr'";
        }
      }

      if (value.kind == InstanceKind.kList) {
        valueStr = '$valueStr (${_itemCount(value.length!)})';
      } else if (value.kind == InstanceKind.kMap) {
        valueStr = '$valueStr (${_itemCount(value.length!)})';
      } else if (value.kind != null && value.kind!.endsWith('List')) {
        // Uint8List, Uint16List, ...
        valueStr = '$valueStr (${_itemCount(value.length!)})';
      }
    } else if (value is Sentinel) {
      valueStr = value.valueAsString!;
    } else if (value is TypeArgumentsRef) {
      valueStr = value.name!;
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
    if (text != null) return text;

    final instanceRef = ref.instanceRef;
    final value = ref.instanceRef is InstanceRef
        ? instanceRef!.valueAsString
        : instanceRef;
    return '$name - $value';
  }

  /// Selects the object in the Flutter Widget inspector.
  ///
  /// Returns whether the inspector selection was changed
  Future<bool> inspectWidget() async {
    if (ref == null || ref.instanceRef == null) {
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
        return await group.setSelection(ref);
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
    if (_isInspectable != null) return _isInspectable;

    if (ref == null) return false;
    final inspectorService = serviceManager.inspectorService;
    if (inspectorService == null) {
      return false;
    }

    // Group name doesn't matter in this case.
    final group = inspectorService.createObjectGroup('inspect-variables');

    try {
      _isInspectable = await group.isInspectable(ref);
    } catch (e) {
      _isInspectable = false;
      // This is somewhat unexpected. The inspectorRef must have been disposed.
    } finally {
      // Not really needed as we shouldn't actually be allocating anything.
      unawaited(group.dispose());
    }
    return _isInspectable;
  }

  bool _isInspectable;

  @override
  DartObjectNode shallowCopy() {
    throw UnimplementedError('This method is not implemented. Implement if you '
        'need to call `shallowCopy` on an instance of this class.');
  }
}

/// A node in a tree of scripts.
///
/// A node can either be a directory (a name with potentially some child nodes),
/// a script reference (where [scriptRef] is non-null), or a combination of both
/// (where the node has a non-null [scriptRef] but also contains child nodes).
class FileNode extends TreeNode<FileNode> {
  FileNode(this.name);

  final String name;

  // This can be null.
  ScriptRef? scriptRef;

  /// This exists to allow for O(1) lookup of children when building the tree.
  final Map<String, FileNode> _childrenAsMap = {};

  bool get hasScript => scriptRef != null;

  String _fileName = '';

  /// Returns the name of the file.
  ///
  /// May be empty.
  String get fileName => _fileName;

  /// Given a flat list of service protocol scripts, return a tree of scripts
  /// representing the best hierarchical grouping.
  static List<FileNode> createRootsFrom(List<ScriptRef> scripts) {
    // The name of this node is not exposed to users.
    final root = FileNode('<root>');

    for (var script in scripts) {
      final directoryParts = ScriptRefUtils.splitDirectoryParts(script);

      FileNode node = root;

      for (var name in directoryParts) {
        node = node._getCreateChild(name);
      }

      node.scriptRef = script;
      node._fileName = ScriptRefUtils.fileName(script);
    }

    // Clear out the _childrenAsMap map.
    root._trimChildrenAsMapEntries();

    return root.children;
  }

  FileNode _getCreateChild(String name) {
    return _childrenAsMap.putIfAbsent(name, () {
      final child = FileNode(name);
      child.parent = this;
      children.add(child);
      return child;
    });
  }

  /// Clear the _childrenAsMap map recursively to save memory.
  void _trimChildrenAsMapEntries() {
    _childrenAsMap.clear();

    for (var child in children) {
      child._trimChildrenAsMapEntries();
    }
  }

  @override
  FileNode shallowCopy() {
    throw UnimplementedError('This method is not implemented. Implement if you '
        'need to call `shallowCopy` on an instance of this class.');
  }

  @override
  int get hashCode => scriptRef?.hashCode ?? name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! FileNode) return false;
    final FileNode node = other;

    if (scriptRef == null) {
      return node.scriptRef != null ? false : name == node.name;
    } else {
      return node.scriptRef == null ? false : scriptRef == node.scriptRef;
    }
  }
}

// ignore: avoid_classes_with_only_static_members
class ScriptRefUtils {
  static String fileName(ScriptRef scriptRef) =>
      Uri.parse(scriptRef.uri!).path.split('/').last;

  /// Return the Uri for the given ScriptRef split into path segments.
  ///
  /// This is useful for converting a flat list of scripts into a directory tree
  /// structure.
  static List<String> splitDirectoryParts(ScriptRef scriptRef) {
    final uri = Uri.parse(scriptRef.uri!);
    final scheme = uri.scheme;
    var parts = uri.path.split('/');

    // handle google3:///foo/bar
    if (parts.first.isEmpty) {
      parts = parts.where((part) => part.isNotEmpty).toList();
      // Combine the first non-empty path segment with the scheme:
      // 'google3:foo'.
      parts = [
        '$scheme:${parts.first}',
        ...parts.sublist(1),
      ];
    } else if (parts.first.contains('.')) {
      // Look for and handle dotted package names (package:foo.bar).
      final dottedParts = parts.first.split('.');
      parts = [
        '$scheme:${dottedParts.first}',
        ...dottedParts.sublist(1),
        ...parts.sublist(1),
      ];
    } else {
      parts = [
        '$scheme:${parts.first}',
        ...parts.sublist(1),
      ];
    }

    if (parts.length > 1) {
      return [
        parts.first,
        parts.sublist(1).join('/'),
      ];
    } else {
      return parts;
    }
  }
}
