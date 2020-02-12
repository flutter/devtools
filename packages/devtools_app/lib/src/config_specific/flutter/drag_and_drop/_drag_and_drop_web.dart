// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:flutter/material.dart';

import '_drag_and_drop_base.dart';

class DragAndDrop extends DragAndDropBase<MouseEvent> {
  const DragAndDrop({
    @required void Function(MouseEvent event) onDrop,
    @required Widget child,
  }) : super(onDrop: onDrop, child: child);

  @override
  _DragAndDropState createState() => _DragAndDropState();
}

class _DragAndDropState extends DragAndDropBaseState<MouseEvent> {
  @override
  void initState() {
    onDragOverSubscription = document.body.onDragOver.listen(onDragOver);
    onDragLeaveSubscription = document.body.onDragLeave.listen(onDragLeave);
    onDropSubscription = document.body.onDrop.listen(onDrop);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void onDragOver(MouseEvent event) {
    super.onDragOver(event);
    // This is necessary to allow us to drop.
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }

  @override
  void onDrop(MouseEvent event) async {
    // Stop the browser from redirecting.
    event.preventDefault();
    super.onDrop(event);
  }
}
