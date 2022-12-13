// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/primitives/trees.dart';
import '../../shared/ui/search.dart';
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
/// reference to an [InspectorInstanceRef]. [value] must be a VM service type,
/// Sentinel, or primitive type.
class GenericInstanceRef {
  GenericInstanceRef({
    required this.isolateRef,
    this.value,
    this.diagnostic,
  });

  final Object? value;

  InstanceRef? get instanceRef =>
      value is InstanceRef ? value as InstanceRef? : null;

  /// If both [diagnostic] and [instanceRef] are provided, [diagnostic.valueRef]
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode? diagnostic;

  final IsolateRef? isolateRef;
}

/// A tuple of a script and an optional location.
class ScriptLocation {
  ScriptLocation(
    this.scriptRef, {
    this.location,
  });

  final ScriptRef scriptRef;

  final SourcePosition? location;

  @override
  bool operator ==(other) {
    return other is ScriptLocation &&
        other.scriptRef == scriptRef &&
        other.location == location;
  }

  @override
  int get hashCode => Object.hash(scriptRef, location);

  @override
  String toString() => '${scriptRef.uri} $location';
}

class SourcePosition {
  const SourcePosition({
    required this.line,
    required this.column,
    this.file,
    this.tokenPos,
  });

  factory SourcePosition.calculatePosition(Script script, int tokenPos) {
    return SourcePosition(
      line: script.getLineNumberFromTokenPos(tokenPos),
      column: script.getColumnNumberFromTokenPos(tokenPos),
      tokenPos: tokenPos,
    );
  }

  final String? file;
  final int? line;
  final int? column;
  final int? tokenPos;

  @override
  bool operator ==(other) {
    return other is SourcePosition &&
        other.line == line &&
        other.column == column &&
        other.tokenPos == tokenPos;
  }

  @override
  int get hashCode =>
      line != null && column != null ? (line! << 7) ^ column! : super.hashCode;

  @override
  String toString() => '$line:$column';
}

class SourceToken with DataSearchStateMixin {
  SourceToken({required this.position, required this.length});

  final SourcePosition position;

  final int length;

  @override
  String toString() {
    return '$position-${position.column! + length}';
  }
}

/// A tuple of a breakpoint and a source position.
abstract class BreakpointAndSourcePosition
    implements Comparable<BreakpointAndSourcePosition> {
  BreakpointAndSourcePosition._(this.breakpoint, [this.sourcePosition]);

  factory BreakpointAndSourcePosition.create(
    Breakpoint breakpoint, [
    SourcePosition? sourcePosition,
  ]) {
    if (breakpoint.location is SourceLocation) {
      return _BreakpointAndSourcePositionResolved(
        breakpoint,
        sourcePosition,
        breakpoint.location as SourceLocation,
      );
    } else if (breakpoint.location is UnresolvedSourceLocation) {
      return _BreakpointAndSourcePositionUnresolved(
        breakpoint,
        sourcePosition,
        breakpoint.location as UnresolvedSourceLocation,
      );
    } else {
      throw 'invalid value for breakpoint.location';
    }
  }

  final Breakpoint breakpoint;
  final SourcePosition? sourcePosition;

  bool get resolved => breakpoint.resolved ?? false;

  ScriptRef? get scriptRef;

  String? get scriptUri;

  int? get line;

  int? get column;

  int? get tokenPos;

  String? get id => breakpoint.id;

  @override
  int get hashCode => breakpoint.hashCode;
  @override
  bool operator ==(other) {
    return other is BreakpointAndSourcePosition &&
        other.breakpoint == breakpoint;
  }

  @override
  int compareTo(BreakpointAndSourcePosition other) {
    final result = scriptUri!.compareTo(other.scriptUri!);
    if (result != 0) return result;

    if (resolved != other.resolved) return resolved ? 1 : -1;

    if (resolved) {
      final otherTokenPos = other.tokenPos;
      if (tokenPos != null && otherTokenPos != null) {
        return tokenPos! - otherTokenPos;
      }
    } else {
      final otherLine = other.line;
      if (line != null && otherLine != null) {
        return line! - otherLine;
      }
    }
    return 0;
  }
}

class _BreakpointAndSourcePositionResolved extends BreakpointAndSourcePosition {
  _BreakpointAndSourcePositionResolved(
    Breakpoint breakpoint,
    SourcePosition? sourcePosition,
    this.location,
  ) : super._(breakpoint, sourcePosition);

  final SourceLocation location;

  @override
  ScriptRef? get scriptRef => location.script;

  @override
  String? get scriptUri => location.script?.uri;

  @override
  int? get tokenPos => location.tokenPos;

  @override
  int? get line => sourcePosition?.line;

  @override
  int? get column => sourcePosition?.column;
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
  ScriptRef? get scriptRef => location.script;

  @override
  String? get scriptUri => location.script?.uri ?? location.scriptUri;

  @override
  int? get tokenPos => location.tokenPos;

  @override
  int? get line => sourcePosition?.line ?? location.line;

  @override
  int? get column => sourcePosition?.column ?? location.column;
}

/// A tuple of a stack frame and a source position.
class StackFrameAndSourcePosition {
  StackFrameAndSourcePosition(
    this.frame, {
    this.position,
  });

  final Frame frame;

  /// This can be null.
  final SourcePosition? position;

  ScriptRef? get scriptRef => frame.location?.script;

  String? get scriptUri => frame.location?.script?.uri;

  int? get line => position?.line;

  int? get column => position?.column;

  String get callStackDisplay {
    final asyncMarker = frame.kind == FrameKind.kAsyncSuspensionMarker;
    return '$description${asyncMarker ? null : ' ($location)'}';
  }

  String get description {
    const unoptimized = '[Unoptimized] ';
    const none = '<none>';
    const anonymousClosure = '<anonymous closure>';
    const closure = '<closure>';
    const asyncBreak = '<async break>';

    if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
      return asyncBreak;
    }

    var name = frame.code?.name ?? none;
    if (name.startsWith(unoptimized)) {
      name = name.substring(unoptimized.length);
    }
    name = name.replaceAll(anonymousClosure, closure);
    name = name == none ? name : '$name';
    return name;
  }

  String? get location {
    final uri = scriptUri;
    if (uri == null) {
      return uri;
    }
    final file = uri.split('/').last;
    return line == null ? file : '$file:$line';
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
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
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

    return parts.length > 1
        ? [
            parts.first,
            parts.sublist(1).join('/'),
          ]
        : parts;
  }
}
