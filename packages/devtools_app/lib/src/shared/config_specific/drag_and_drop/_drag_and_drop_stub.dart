// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'drag_and_drop.dart';

// ignore: avoid-unused-parameters, method is used from a conditional import
DragAndDropManager createDragAndDropManager(int viewId) {
  throw Exception(
    'Attempting to create DragAndDrop for unrecognized platform.',
  );
}
