// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'drag_and_drop.dart';

// TODO(kenz): implement once Desktop support is available. See
// https://github.com/flutter/flutter/issues/30719.

DragAndDropManagerDesktop createDragAndDropManager(int viewId) {
  return DragAndDropManagerDesktop(viewId);
}

class DragAndDropManagerDesktop extends DragAndDropManager {
  DragAndDropManagerDesktop(super.viewId) : super.impl();

  @override
  void init() {}
}
