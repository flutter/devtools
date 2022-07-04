// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose.dart';
import 'object_viewport.dart';
import 'vm_object_model.dart';

/// Stores the state information for the object inspector view related to
/// the object history and the object viewport.
class ObjectInspectorViewController extends DisposableController
    with AutoDisposeControllerMixin {
  final objectHistory = ObjectHistory();

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  Future<void> refreshObject() async {
    _refreshing.value = true;

    final objRef = objectHistory.current.value?.ref;

    if (objRef != null) {
      final refetchedObject = await createVmObject(objRef);
      if (refetchedObject != null) {
        objectHistory.replaceCurrent(refetchedObject);
      }
    }

    _refreshing.value = false;
  }

  Future<void> pushObject(ObjRef objRef) async {
    _refreshing.value = true;
    final object = await createVmObject(objRef);
    if (object != null) {
      objectHistory.pushEntry(object);
    }
    _refreshing.value = false;
  }

  Future<VmObject?> createVmObject(ObjRef objRef) async {
    VmObject? object;
    if (objRef is ClassRef) {
      object = ClassObject(ref: objRef);
    } else if (objRef is FuncRef) {
      object = FuncObject(ref: objRef);
    } else if (objRef is FieldRef) {
      object = FieldObject(ref: objRef);
    } else if (objRef is LibraryRef) {
      object = LibraryObject(ref: objRef);
    } else if (objRef is ScriptRef) {
      object = ScriptObject(ref: objRef);
    } else if (objRef is InstanceRef) {
      object = InstanceObject(ref: objRef);
    }

    await object?.initialize();

    return object;
  }
}
