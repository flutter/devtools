// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'heap_data.dart';

/// API for working with heap data.
class Heap {
  Heap(this.data);

  final HeapData data;
}

/// API for working with a heap object.
class HeapObject {
  HeapObject(this.data, {required this.index});

  final HeapData data;
  final int index;
}
