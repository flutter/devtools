// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../globals.dart';

class EvalScope {
  /// Parameter `scope` for `serviceManager.service!.evaluate(...)`.
  ///
  /// Maps variable name to targetId.
  Map<String, String> value({required String isolateId}) =>
      (_refs[isolateId] ?? {}).map((key, value) => MapEntry(key, value.id!));

  /// Maps isolate name to list of context variables.
  final _refs = <String, Map<String, InstanceRef>>{};

  void add(String isolateId, String variableName, InstanceRef ref) {
    _refs.putIfAbsent(isolateId, () => {});
    _refs[isolateId]![variableName] = ref;
  }

  /// If scope variables changed during refresh, this field will contain message to show to user.
  String? refreshScopeChangeMessage;

  /// Refreshes variables in scope in response to failed eval.
  ///
  /// Returns true, if eval should retry.
  /// Sets [refreshScopeChangeMessage] if scope changed.
  bool refreshRefs(String isolateId) {
    refreshScopeChangeMessage = null;
    var result = false;

    for (final name in _refs.keys) {}
    return result;
  }

  Future<InstanceRef?> _refreshRef(
    InstanceRef ref,
    IsolateRef isolateRef,
  ) async {
    final isolateId = isolateRef.id;
    if (isolateId == null) return null;

    Obj? result;

    try {
      result = await serviceManager.service!.getObject(
        isolateId,
        ref.id!,
      );
    } catch (e) {
      // If we could not get object, we need to recover it
    }

    // For some reasons type is not promoted here :(.
    if (result is InstanceRef) return result as InstanceRef;

    return null;
  }
}
