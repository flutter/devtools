// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/globals.dart';
import '../vm_service_private_extensions.dart';

class ObjectStoreController extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<ObjectStore?> get selectedIsolateObjectStore =>
      _selectedIsolateObjectStore;
  final _selectedIsolateObjectStore = ValueNotifier<ObjectStore?>(null);

  Future<void> refresh() async {
    final service = serviceConnection.serviceManager.service!;
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    if (isolate == null) {
      return;
    }
    _selectedIsolateObjectStore.value = null;
    _selectedIsolateObjectStore.value =
        await service.getObjectStore(isolate.id!);
  }
}
