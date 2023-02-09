// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../eval_on_dart_library.dart';
import 'primitives/instance_ref.dart';

abstract class ObjectGroupApi<T extends DiagnosticableTree>
    implements Disposable {
  bool get canSetSelectionInspector => false;

  Future<bool> setSelectionInspector(
    InspectorInstanceRef selection,
    bool uiAlreadyUpdated,
  ) =>
      throw UnimplementedError();

  Future<Map<String, InstanceRef>?> getEnumPropertyValues(
    InspectorInstanceRef ref,
  );

  Future<Map<String, InstanceRef>?> getDartObjectProperties(
    InspectorInstanceRef inspectorInstanceRef,
    final List<String> propertyNames,
  );

  Future<List<T>> getChildren(
    InspectorInstanceRef instanceRef,
    bool summaryTree,
    T? parent,
  );

  bool isLocalClass(T node);

  Future<InstanceRef?> toObservatoryInstanceRef(
    InspectorInstanceRef inspectorInstanceRef,
  );

  Future<List<T>> getProperties(InspectorInstanceRef instanceRef);
}
