// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'drag_and_drop.dart';

// TODO(kenz): implement once Desktop support is available. See
// https://github.com/flutter/flutter/issues/30719.

DragAndDropDesktop createDragAndDrop({
  @required void Function(Map<String, dynamic> data) handleDrop,
  @required Widget child,
}) {
  return DragAndDropDesktop(handleDrop: handleDrop, child: child);
}

class DragAndDropDesktop extends DragAndDrop {
  const DragAndDropDesktop({
    @required void Function(Map<String, dynamic> data) handleDrop,
    @required Widget child,
  }) : super.impl(handleDrop: handleDrop, child: child);

  @override
  _DragAndDropDesktopState createState() => _DragAndDropDesktopState();
}

class _DragAndDropDesktopState extends DragAndDropState {}
