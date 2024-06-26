// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import 'dart_object_node.dart';

/// Gets object by object reference using offset and childCount from [variable]
/// for list items.
Future<Object?> getObject({
  required IsolateRef? isolateRef,
  required ObjRef value,
  DartObjectNode? variable,
}) async {
  // Don't include the offset and count parameters if we are not fetching a
  // partial object. Offset and count parameters are only necessary to request
  // subranges of the following instance kinds:
  // https://api.flutter.dev/flutter/vm_service/VmServiceInterface/getObject.html
  if (variable == null || !variable.isPartialObject) {
    return await serviceConnection.serviceManager.service!.getObject(
      isolateRef!.id!,
      value.id!,
    );
  }

  return await serviceConnection.serviceManager.service!.getObject(
    isolateRef!.id!,
    value.id!,
    offset: variable.offset,
    count: variable.childCount,
  );
}

bool isList(ObjRef? ref) {
  if (ref is! InstanceRef) return false;
  final kind = ref.kind;
  if (kind == null) return false;
  return kind.endsWith('List') || kind == InstanceKind.kList;
}
