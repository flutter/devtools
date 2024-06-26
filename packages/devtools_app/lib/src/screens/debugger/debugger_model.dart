// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/ui/search.dart';

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

/// A tuple of a script and an optional location.
class ScriptLocation {
  ScriptLocation(
    this.scriptRef, {
    this.location,
  });

  final ScriptRef scriptRef;

  final SourcePosition? location;

  @override
  bool operator ==(Object other) {
    return other is ScriptLocation &&
        other.scriptRef == scriptRef &&
        other.location == location;
  }

  @override
  int get hashCode => Object.hash(scriptRef, location);

  @override
  String toString() => '${scriptRef.uri} $location';
}

class SourceToken with SearchableDataMixin {
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
  bool operator ==(Object other) {
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
    super.breakpoint,
    super.sourcePosition,
    this.location,
  ) : super._();

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
    super.breakpoint,
    super.sourcePosition,
    this.location,
  ) : super._();

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
    const asyncBreak = '<async break>';

    if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
      return asyncBreak;
    }

    var name = frame.code?.name ?? none;
    if (name.startsWith(unoptimized)) {
      name = name.substring(unoptimized.length);
    }
    name = name.replaceAll(anonymousClosureName, closureName);

    if (frame.code?.kind == CodeKind.kNative) {
      return '<native code: $name>';
    }

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

// ignore: avoid_classes_with_only_static_members, fine for utility method.
abstract class ScriptRefUtils {
  static String fileName(ScriptRef scriptRef) =>
      Uri.parse(scriptRef.uri!).path.split('/').last;
}
