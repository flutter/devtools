// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';

Future<HeapSnapshotGraph?> snapshotMemory() async {
  final isolate = serviceManager.isolateManager.selectedIsolate.value;
  if (isolate == null) return null;
  return await serviceManager.service?.getHeapSnapshotGraph(
    isolate,
  );
}

String? get currentIsolateName =>
    serviceManager.isolateManager.selectedIsolate.value?.name;
