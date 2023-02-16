// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../globals.dart';

class EvalScope {
  /// Parameter `scope` for `serviceManager.service!.evaluate(...)`.
  ///
  /// Maps variable name to targetId.
  Map<String, String> forEval() {
    _refreshRefsIfOutdated();
    return _refs.map((key, value) => MapEntry(key, value.id!));
  }

  DateTime _lastRefresh = DateTime.now();

  final _refs = <String, InstanceRef>{};

  void add(String name, InstanceRef ref) {
    if (_refs.isEmpty) _lastRefresh = DateTime.now();
    _refs[name] = ref;
  }

  /// If variables live too long, refresh them to avoid hitting expired references.
  void _refreshRefsIfOutdated() {
    if (_refs.isEmpty) return;
    const refreshThreshold = Duration(milliseconds: 500);
    if (_lastRefresh.add(refreshThreshold).isBefore(DateTime.now())) return;

    for (final name in _refs.keys) {}

    _lastRefresh = DateTime.now();
  }

  Future<InstanceRef?> refreshRef(
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
