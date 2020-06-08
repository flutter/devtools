// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../notifications.dart';
import '_drag_and_drop_stub.dart'
    if (dart.library.html) '_drag_and_drop_web.dart'
    if (dart.library.io) '_drag_and_drop_desktop.dart';

abstract class DragAndDrop extends StatefulWidget {
  factory DragAndDrop({
    @required Function(Map<String, dynamic> data) handleDrop,
    @required Widget child,
  }) {
    return createDragAndDrop(
      handleDrop: handleDrop,
      child: child,
    );
  }

  const DragAndDrop.impl({@required this.handleDrop, @required this.child});

  /// Callback to handle parsed data from drag and drop.
  ///
  /// The current implementation expects data in json format.
  final void Function(Map<String, dynamic> data) handleDrop;

  final Widget child;
}

abstract class DragAndDropState extends State<DragAndDrop> {
  final _dragging = ValueNotifier<bool>(false);

  NotificationsState notifications;

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

  void dragOver() {
    _dragging.value = true;
  }

  void dragLeave() {
    _dragging.value = false;
  }

  void drop() {
    _dragging.value = false;
  }
}
