// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/heap/model.dart';

class ProfileRecord {
  ProfileRecord({
    required this.heapClass,
    required this.instances,
    required this.newDartSize,
    required this.oldDartSize,
    required this.newExternalSize,
    required this.oldExternalSize,
  });

  ProfileRecord.fromClassHeapStats(ClassHeapStats stats)
      : heapClass = HeapClass.fromClassRef(stats.classRef);

  final HeapClass heapClass;
  final int instances;
  final int newDartSize;
  final int oldDartSize;
  final int newExternalSize;
  final int oldExternalSize;
}
