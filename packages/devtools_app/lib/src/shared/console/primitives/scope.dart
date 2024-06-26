// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../globals.dart';
import '../../vm_utils.dart';

class EvalScope {
  /// Parameter `scope` for `serviceManager.manager.service!.evaluate(...)`.
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

  /// List of variables, removed during last refresh.
  final removedVariables = <String>[];

  /// Refreshes variables in scope in response to failed eval.
  ///
  /// Returns true, if eval should retry.
  /// Sets [refreshScopeChangeMessage] if scope changed.
  Future<bool> refreshRefs(String isolateId) async {
    removedVariables.clear();
    final isolateItems = _refs[isolateId] ?? {};
    var result = false;

    final variableNames = [...isolateItems.keys];
    for (final name in variableNames) {
      final oldItem = isolateItems[name]!;
      final refreshedItem = await _refreshRef(oldItem, isolateId);
      if (refreshedItem != oldItem) result = true;
      if (refreshedItem == null) {
        isolateItems.remove(name);
        removedVariables.add(name);
      }
    }

    return result;
  }

  Future<InstanceRef?> _refreshRef(
    InstanceRef ref,
    String isolateId,
  ) async {
    Obj? object;
    try {
      object = await serviceConnection.serviceManager.service!.getObject(
        isolateId,
        ref.id!,
      );
    } on RPCError {
      // If we could not get object, we need to recover it.
    } on SentinelException {
      // If we could not get object, we need to recover it.
    }
    if (object != null) return ref;

    return await findInstance(
      isolateId,
      ref.classRef?.id,
      ref.identityHashCode,
    );
  }
}
