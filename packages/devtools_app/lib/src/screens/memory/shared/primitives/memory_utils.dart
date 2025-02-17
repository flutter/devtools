// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';

Future<HeapSnapshotGraph?> snapshotMemoryInSelectedIsolate() async {
  final isolate =
      serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
  if (isolate == null) return null;
  return await serviceConnection.serviceManager.service?.getHeapSnapshotGraph(
    isolate,
    decodeExternalProperties: false,
    decodeObjectData: false,
  );
}

String? get selectedIsolateName =>
    serviceConnection.serviceManager.isolateManager.selectedIsolate.value?.name;
