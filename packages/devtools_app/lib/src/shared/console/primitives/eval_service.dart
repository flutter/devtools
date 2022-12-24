// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../object_tree.dart';
import '../../primitives/reference.dart';

typedef ExpressionEvaluator = Future<Response> Function(String expression);

class EvalService {
  EvalService(this.isolateRef, this.variables, this.evalAtCurrentFrame);

  final Reference<IsolateRef?> isolateRef;

  final ValueListenable<List<DartObjectNode>> variables;

  final ExpressionEvaluator evalAtCurrentFrame;

  final EvalHistory evalHistory = EvalHistory();

  String get _isolateRefId {
    final id = isolateRef.value?.id;
    if (id == null) return '';
    return id;
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return serviceManager.service!.getObject(_isolateRefId, objRef.id!);
  }

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.
  final libraryMemberAutocompleteCache = <LibraryRef, Future<Set<String?>>>{};
}

/// Store and manipulate the expression evaluation history.
class EvalHistory {
  var _historyPosition = -1;

  /// Get the expression evaluation history.
  List<String> get evalHistory => _evalHistory.toList();

  final _evalHistory = <String>[];

  /// Push a new entry onto the expression evaluation history.
  void pushEvalHistory(String expression) {
    if (_evalHistory.isNotEmpty && _evalHistory.last == expression) {
      return;
    }

    _evalHistory.add(expression);
    _historyPosition = -1;
  }

  bool get canNavigateUp {
    return _evalHistory.isNotEmpty && _historyPosition != 0;
  }

  void navigateUp() {
    if (_historyPosition == -1) {
      _historyPosition = _evalHistory.length - 1;
    } else if (_historyPosition > 0) {
      _historyPosition--;
    }
  }

  bool get canNavigateDown {
    return _evalHistory.isNotEmpty && _historyPosition != -1;
  }

  void navigateDown() {
    if (_historyPosition != -1) {
      _historyPosition++;
    }
    if (_historyPosition >= _evalHistory.length) {
      _historyPosition = -1;
    }
  }

  String? get currentText {
    return _historyPosition == -1 ? null : _evalHistory[_historyPosition];
  }
}
