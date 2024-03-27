// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';

Future<HeapSnapshotGraph?> snapshotMemoryInSelectedIsolate() async {
  final isolate =
      serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
  if (isolate == null) return null;
  return await serviceConnection.serviceManager.service?.getHeapSnapshotGraph(
    isolate,
    calculateReferrers: false,
    decodeExternalProperties: false,
    decodeObjectData: false,
  );
}

String? get selectedIsolateName =>
    serviceConnection.serviceManager.isolateManager.selectedIsolate.value?.name;

String? get selectedIsolateId =>
    serviceConnection.serviceManager.isolateManager.selectedIsolate.value?.id;
