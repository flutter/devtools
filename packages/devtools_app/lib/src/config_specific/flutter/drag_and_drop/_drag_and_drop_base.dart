// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

abstract class DragAndDropBase<T> extends StatefulWidget {
  const DragAndDropBase({@required this.onDrop, @required this.child});

  final void Function(T event) onDrop;

  final Widget child;
}

abstract class DragAndDropBaseState<T> extends State<DragAndDropBase<T>> {
  StreamSubscription<T> onDragOverSubscription;
  StreamSubscription<T> onDropSubscription;
  StreamSubscription<T> onDragLeaveSubscription;

  final dragging = ValueNotifier<bool>(false);

  @override
  void dispose() {
    onDragOverSubscription?.cancel();
    onDragLeaveSubscription?.cancel();
    onDropSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: dragging,
      builder: (context, dragging, _) {
        return Opacity(
          opacity: dragging ? 0.5 : 1.0,
          child: widget.child,
        );
      },
    );
  }

  @mustCallSuper
  void onDragOver(T event) {
    dragging.value = true;
  }

  @mustCallSuper
  void onDragLeave(T event) {
    dragging.value = false;
  }

  @mustCallSuper
  void onDrop(T event) {
    dragging.value = false;
    widget.onDrop(event);
  }
}
