// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../notifications.dart';
import '_drag_and_drop_stub.dart'
    if (dart.library.html) '_drag_and_drop_web.dart'
    if (dart.library.io) '_drag_and_drop_desktop.dart';

/// Contains the priority for [DragAndDrop] widget keys throughout DevTools.
///
/// When a key is in the top list of keys in the queue, the associated
/// [DragAndDrop] widget's listeners are allowed to fire. Each drag and drop key
/// in DevTools must be unique.
QueueList<List<Key>> _dragAndDropPriorityQueue = QueueList();

void addDragAndDropPriorityKeys(List<Key> keys) {
  _dragAndDropPriorityQueue.add(keys);
}

abstract class DragAndDrop extends StatefulWidget {
  factory DragAndDrop({
    @required Key key,
    @required Function(Map<String, dynamic> data) handleDrop,
    @required Widget child,
  }) {
    return createDragAndDrop(
      key: key,
      handleDrop: handleDrop,
      child: child,
    );
  }

  const DragAndDrop.impl({
    @required Key key,
    @required this.handleDrop,
    @required this.child,
  }) : super(key: key);

  /// Callback to handle parsed data from drag and drop.
  ///
  /// The current implementation expects data in json format.
  final void Function(Map<String, dynamic> data) handleDrop;

  final Widget child;
}

abstract class DragAndDropState extends State<DragAndDrop> {
  final _dragging = ValueNotifier<bool>(false);

  NotificationsState notifications;

  bool get isPriority =>
      _dragAndDropPriorityQueue.isNotEmpty &&
      _dragAndDropPriorityQueue.last.contains(widget.key);

  @override
  void dispose() {
    super.dispose();
    // Remove [widget.key] from [_dragAndDropPriorityQueue]. We need to traverse
    // through the list backwards because [widget.key] is not guaranteed to be
    // in the top list of keys in [_dragAndDropPriorityQueue]. If another widget
    // containing a [DragAndDrop] widget is initiated before [this] is disposed,
    // then the top list of keys will not be the list containing [widget.key].
    for (int i = _dragAndDropPriorityQueue.length - 1; i >= 0; i--) {
      final list = _dragAndDropPriorityQueue[i];
      if (list.contains(widget.key)) {
        list.remove(widget.key);
        if (list.isEmpty) {
          _dragAndDropPriorityQueue.remove(list);
        }
        return;
      }
    }
  }

  @override
  void didChangeDependencies() {
    notifications = Notifications.of(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _dragging,
      builder: (context, dragging, _) {
        // TODO(kenz): use AnimatedOpacity instead.
        return Opacity(
          opacity: dragging ? 0.5 : 1.0,
          child: widget.child,
        );
      },
    );
  }

  void dragOver(double x, double y) {
    _dragging.value = coordinatesInBound(x, y);
  }

  void dragLeave() {
    _dragging.value = false;
  }

  void drop() {
    _dragging.value = false;
  }

  bool coordinatesInBound(double x, double y) {
    final RenderBox renderBox = context.findRenderObject();
    final globalToLocalOffset = renderBox.globalToLocal(Offset(x, y));
    return globalToLocalOffset.dx >= 0.0 &&
        globalToLocalOffset.dy >= 0.0 &&
        globalToLocalOffset.dx <= renderBox.constraints.maxWidth &&
        globalToLocalOffset.dy <= renderBox.constraints.maxHeight;
  }
}
