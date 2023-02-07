// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import 'dart_object_node.dart';

/// Gets object by object reference using offset and childCount from [variable]
/// to get list items.
Future<Object?> getObject({
  required IsolateRef? isolateRef,
  required ObjRef value,
  DartObjectNode? variable,
}) async {
  return await serviceManager.service!.getObject(
    isolateRef!.id!,
    value.id!,
    offset: variable?.offset,
    count: variable?.childCount,
  );
}
