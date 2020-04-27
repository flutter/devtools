// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

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
      Breakpoint breakpoint, SourcePosition sourcePosition, this.location)
      : super._(breakpoint, sourcePosition);

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
  StackFrameAndSourcePosition._(this.frame, this.sourcePosition);

  factory StackFrameAndSourcePosition.create(
    Frame frame, {
    SourcePosition position,
  }) {
    return StackFrameAndSourcePosition._(frame, position);
  }

  final Frame frame;

  /// This can be null.
  final SourcePosition sourcePosition;

  ScriptRef get scriptRef => frame.location?.script;

  String get scriptUri => frame.location?.script?.uri;

  int get line => sourcePosition?.line;

  int get column => sourcePosition?.column;
}
