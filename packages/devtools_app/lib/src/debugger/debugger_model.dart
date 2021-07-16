// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../inspector/diagnostics_node.dart';
import '../inspector/inspector_service.dart';
import '../trees.dart';
import '../ui/search.dart';
import '../utils.dart';

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
    @required this.isolateRef,
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

  final Object value;

  InstanceRef get instanceRef => value is InstanceRef ? value : null;

  /// If both [diagnostic] and [instanceRef] are provided, [diagnostic.valueRef]
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode diagnostic;

  final IsolateRef isolateRef;
}

/// A tuple of a script and an optional location.
class ScriptLocation {
  ScriptLocation(this.scriptRef, {this.location});

  final ScriptRef scriptRef;

  /// This field can be null.
  final SourcePosition location;

  @override
  bool operator ==(other) {
    return other is ScriptLocation &&
        other.scriptRef == scriptRef &&
        other.location == location;
  }

  @override
  int get hashCode => hashValues(scriptRef, location);

  @override
  String toString() => '${scriptRef.uri} $location';
}

/// A line, column, and an optional tokenPos.
class SourcePosition {
  SourcePosition({@required this.line, @required this.column, this.tokenPos});

  final int line;
  final int column;
  final int tokenPos;

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
  SourceToken({@required this.position, @required this.length});

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
      [SourcePosition sourcePosition]) {
    if (breakpoint.location is SourceLocation) {
      return _BreakpointAndSourcePositionResolved(
          breakpoint, sourcePosition, breakpoint.location as SourceLocation);
    } else if (breakpoint.location is UnresolvedSourceLocation) {
      return _BreakpointAndSourcePositionUnresolved(breakpoint, sourcePosition,
          breakpoint.location as UnresolvedSourceLocation);
    } else {
      throw 'invalid value for breakpoint.location';
    }
  }

  final Breakpoint breakpoint;
  final SourcePosition sourcePosition;

  bool get resolved => breakpoint.resolved;

  ScriptRef get scriptRef;

  String get scriptUri;

  int get line;

  int get column;

  int get tokenPos;

  String get id => breakpoint.id;

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
  ScriptRef get scriptRef => location.script;

  @override
  String get scriptUri => location.script.uri;

  @override
  int get tokenPos => location.tokenPos;

  @override
  int get line => sourcePosition?.line;

  @override
  int get column => sourcePosition?.column;
}

class _BreakpointAndSourcePositionUnresolved
    extends BreakpointAndSourcePosition {
  _BreakpointAndSourcePositionUnresolved(
    Breakpoint breakpoint,
    SourcePosition sourcePosition,
    this.location,
  ) : super._(breakpoint, sourcePosition);

  final UnresolvedSourceLocation location;

  @override
  ScriptRef get scriptRef => location.script;

  @override
  String get scriptUri => location.script?.uri ?? location.scriptUri;

  @override
  int get tokenPos => location.tokenPos;

  @override
  int get line => sourcePosition?.line ?? location.line;

  @override
  int get column => sourcePosition?.column ?? location.column;
}

/// A tuple of a stack frame and a source position.
class StackFrameAndSourcePosition {
  StackFrameAndSourcePosition(
    this.frame, {
    this.position,
  });

  final Frame frame;

  /// This can be null.
  final SourcePosition position;

  ScriptRef get scriptRef => frame.location?.script;

  String get scriptUri => frame.location?.script?.uri;

  int get line => position?.line;

  int get column => position?.column;
}

Future<void> addExpandableChildren(
  Variable variable,
  List<Variable> children, {
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

/// Builds the tree representation for a [Variable] object by querying data,
/// creating child Variable objects, and assigning parent-child relationships.
///
/// We call this method as we expand variables in the variable tree, because
/// building the tree for all variable data at once is very expensive.
Future<void> buildVariablesTree(
  Variable variable, {
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
          service,
          properties,
          isolateRef,
        ),
        expandAll: true,
      );
    }

    if (diagnostic.inlineProperties?.isNotEmpty ?? false) {
      await _addPropertiesHelper(diagnostic.inlineProperties);
    } else {
      assert(!service.disposed);
      if (!service.disposed) {
        await _addPropertiesHelper(await diagnostic.getProperties(service));
      }
    }
  }
  final existingNames = <String>{};
  for (var child in variable.children) {
    final name = child?.name;
    if (name != null && name.isNotEmpty) {
      existingNames.add(name);
      if (!isPrivate(name)) {
        // Assume private and public names with the same name reference the same
        // data so showing both is not useful.
        existingNames.add('_$name');
      }
    }
  }
  if (instanceRef != null) {
    try {
      final dynamic result = await serviceManager.service
          .getObject(variable.ref.isolateRef.id, instanceRef.id);
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
    final ObjectGroup service = diagnostic.inspectorService;
    final diagnosticChildren = await diagnostic.children;
    if (diagnosticChildren?.isNotEmpty ?? false) {
      final childrenNode = Variable.text(
        pluralize('child', diagnosticChildren.length, plural: 'children'),
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
    ObjectGroup group;
    Future<void> _maybeUpdateRef(Variable child) async {
      if (child.ref == null) return;
      if (child.ref.diagnostic == null) {
        // TODO(jacobr): also check whether the InstanceRef is an instance of
        // Diagnosticable and show the Diagnosticable properties in that case.
        final instanceRef = child.ref.instanceRef;
        // This is an approximation of eval('instanceRef is DiagnosticsNode')
        // TODO(jacobr): cache the full class hierarchy so we can cheaply check
        // instanceRef is DiagnosticsNode without having to do an eval.
        if (instanceRef != null &&
            (instanceRef.classRef.name == 'DiagnosticableTreeNode' ||
                instanceRef.classRef.name == 'DiagnosticsProperty')) {
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
              value: valueInstanceRef,
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
      unawaited(group?.dispose());
    }
  }
  variable.treeInitializeComplete = true;
}

Future<Variable> _buildVariable(
  RemoteDiagnosticsNode diagnostic,
  ObjectGroup inspectorService,
  IsolateRef isolateRef,
) async {
  final instanceRef =
      await inspectorService.toObservatoryInstanceRef(diagnostic.valueRef);
  return Variable.fromValue(
    name: diagnostic.name,
    value: instanceRef,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
  );
}

Future<List<Variable>> _createVariablesForDiagnostics(
  ObjectGroup inspectorService,
  List<RemoteDiagnosticsNode> diagnostics,
  IsolateRef isolateRef,
) async {
  final variables = <Future<Variable>>[];
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

List<Variable> _createVariablesForAssociations(
  Instance instance,
  IsolateRef isolateRef,
) {
  final variables = <Variable>[];
  for (var i = 0; i < instance.associations.length; i++) {
    final association = instance.associations[i];
    if (association.key is! InstanceRef) {
      continue;
    }
    final key = Variable.fromValue(
      name: '[key]',
      value: association.key,
      isolateRef: isolateRef,
    );
    final value = Variable.fromValue(
      name: '[value]',
      value: association.value,
      isolateRef: isolateRef,
    );
    variables.add(
      Variable.text('[Entry $i]')
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
List<Variable> _createVariablesForBytes(
  Instance instance,
  IsolateRef isolateRef,
) {
  final bytes = base64.decode(instance.bytes);
  final variables = <Variable>[];
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
        return <Variable>[];
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
        return <Variable>[];
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
    variables.add(
      Variable.fromValue(
        name: '[$i]',
        value: result[i],
        isolateRef: isolateRef,
      ),
    );
  }
  return variables;
}

List<Variable> _createVariablesForElements(
  Instance instance,
  IsolateRef isolateRef,
) {
  final variables = <Variable>[];
  for (int i = 0; i < instance.elements.length; i++) {
    variables.add(
      Variable.fromValue(
        name: '[$i]',
        value: instance.elements[i],
        isolateRef: isolateRef,
      ),
    );
  }
  return variables;
}

List<Variable> _createVariablesForFields(
  Instance instance,
  IsolateRef isolateRef, {
  Set<String> existingNames,
}) {
  final variables = <Variable>[];
  for (var field in instance.fields) {
    final name = field.decl.name;
    if (existingNames != null && existingNames.contains(name)) continue;
    variables.add(
      Variable.fromValue(
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
// TODO(jacobr): consider a new class name. This class is more just the data
// model for a tree of Dart objects with properties rather than a "Variable".
class Variable extends TreeNode<Variable> {
  Variable._(this.name, ref, this.text) : _ref = ref {
    indentChildren = ref?.diagnostic?.style != DiagnosticsTreeStyle.flat;
  }

  /// Creates a variable from a value that must be an InstanceRef or a primitive
  /// type.
  ///
  /// [value] should typically be an [InstanceRef] but can also be a [Sentinel]
  /// [ObjRef] or primitive type such as num or String.
  factory Variable.fromValue({
    String name = '',
    @required Object value,
    RemoteDiagnosticsNode diagnostic,
    @required IsolateRef isolateRef,
  }) {
    return Variable._(
      name,
      GenericInstanceRef(
        isolateRef: isolateRef,
        diagnostic: diagnostic,
        value: value,
      ),
      null,
    );
  }

  factory Variable.create(
    BoundVariable variable,
    IsolateRef isolateRef,
  ) {
    final value = variable.value;
    return Variable._(
      variable.name,
      GenericInstanceRef(
        isolateRef: isolateRef,
        value: value,
      ),
      null,
    );
  }

  factory Variable.text(String text) {
    return Variable._(null, null, text);
  }

  final String text;
  final String name;
  GenericInstanceRef get ref => _ref;
  GenericInstanceRef _ref;

  bool treeInitializeStarted = false;
  bool treeInitializeComplete = false;

  @override
  bool get isExpandable {
    if (treeInitializeComplete || children.isNotEmpty) {
      return children.isNotEmpty;
    }
    final diagnostic = ref.diagnostic;
    if (diagnostic != null &&
        ((diagnostic.inlineProperties?.isNotEmpty ?? false) ||
            diagnostic.hasChildren)) return true;
    // TODO(jacobr): do something smarter to avoid expandable variable flicker.
    final instanceRef = ref.instanceRef;
    return instanceRef != null ? instanceRef.valueAsString == null : false;
  }

  Object get value => ref?.value;

  // TODO(kenz): add custom display for lists with more than 100 elements
  String get displayValue {
    if (text != null) {
      return text;
    }
    final value = this.value;

    String valueStr;

    if (value == null) return null;

    if (value is InstanceRef) {
      if (value.valueAsString == null) {
        valueStr = value.classRef.name;
      } else {
        valueStr = value.valueAsString;
        if (value.valueAsStringIsTruncated == true) {
          valueStr += '...';
        }
        if (value.kind == InstanceKind.kString) {
          // TODO(devoncarew): Handle multi-line strings.
          valueStr = "'$valueStr'";
        }
      }

      if (value.kind == InstanceKind.kList) {
        valueStr = '$valueStr (${_itemCount(value.length)})';
      } else if (value.kind == InstanceKind.kMap) {
        valueStr = '$valueStr (${_itemCount(value.length)})';
      } else if (value.kind != null && value.kind.endsWith('List')) {
        // Uint8List, Uint16List, ...
        valueStr = '$valueStr (${_itemCount(value.length)})';
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
    if (text != null) return text;

    final instanceRef = ref.instanceRef;
    final value = ref.instanceRef is InstanceRef
        ? instanceRef.valueAsString
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
  Variable shallowCopy() {
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
  ScriptRef scriptRef;

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

class ScriptRefUtils {
  static String fileName(ScriptRef scriptRef) =>
      Uri.parse(scriptRef.uri).path.split('/').last;

  /// Return the Uri for the given ScriptRef split into path segments.
  ///
  /// This is useful for converting a flat list of scripts into a directory tree
  /// structure.
  static List<String> splitDirectoryParts(ScriptRef scriptRef) {
    final uri = Uri.parse(scriptRef.uri);
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
