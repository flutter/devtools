// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/primitives/instance_set_view.dart';

class HeapSampleObtainer extends SampleObtainer {
  HeapSampleObtainer(this.classId);

  final int classId;

  void classInstance() {}
}
