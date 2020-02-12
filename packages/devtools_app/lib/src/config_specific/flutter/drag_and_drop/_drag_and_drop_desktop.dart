// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_drag_and_drop_base.dart';

// TODO(kenz): implement once Desktop support is available. See
// https://github.com/flutter/flutter/issues/30719.

class DragAndDrop extends DragAndDropBase<PointerEvent> {
  const DragAndDrop({
    @required void Function(PointerEvent event) onDrop,
    @required Widget child,
  }) : super(onDrop: onDrop, child: child);

  @override
  _DragAndDropState createState() => _DragAndDropState();
}

class _DragAndDropState extends DragAndDropBaseState<PointerEvent> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void onDragLeave(PointerEvent event) {
    super.onDragLeave(event);
  }

  @override
  void onDragOver(PointerEvent event) {
    super.onDragOver(event);
  }

  @override
  void onDrop(PointerEvent event) {
    super.onDrop(event);
  }
}
