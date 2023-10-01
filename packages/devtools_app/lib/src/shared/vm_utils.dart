// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

import 'globals.dart';
import 'memory/class_name.dart';

bool isPrimitiveInstanceKind(String? kind) {
  return kind == InstanceKind.kBool ||
      kind == InstanceKind.kDouble ||
      kind == InstanceKind.kInt ||
      kind == InstanceKind.kNull ||
      kind == InstanceKind.kString;
}

Future<ClassRef?> findClass(String? isolateId, HeapClassName className) async {
  if (isolateId == null) return null;
  final service = serviceConnection.serviceManager.service;
  if (service == null) return null;
  final classes = await service.getClassList(isolateId);
  return classes.classes?.firstWhere((ref) => className.matches(ref));
}

/// Finds instance in isolate by class and identityHashCode.
Future<InstanceRef?> findInstance(
  String? isolateId,
  String? classId,
  int? hashCode,
) async {
  if (classId == null ||
      isolateId == null ||
      hashCode == null ||
      hashCode == 0) {
    return null;
  }

  final result = (await serviceConnection.serviceManager.service!.getInstances(
    isolateId,
    classId,
    preferences.memory.refLimit.value,
  ))
      .instances
      ?.firstWhereOrNull(
        (instance) =>
            (instance is InstanceRef) &&
            (instance.identityHashCode == hashCode),
      );

  if (result is InstanceRef) return result;
  return null;
}
