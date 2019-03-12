// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import '../ui/elements.dart';

class DragScroll {
  /// Whether the element was dragged on the previous click.
  bool wasDragged = false;

  void enableDragScrolling(CoreElement element) {
    final dragged = element.element;

    num lastX;
    num lastY;
    bool clicked = false;

    dragged.onMouseDown.listen((event) {
      final MouseEvent m = event;
      clicked = true;
      wasDragged = false;

      lastX = m.client.x;
      lastY = m.client.y;

      m.preventDefault();
    });

    window.onMouseUp.listen((event) => clicked = false);

    window.onMouseMove.listen((event) {
      final MouseEvent m = event;
      if (clicked) {
        final num newX = m.client.x;
        final num newY = m.client.y;

        final num deltaX = lastX - newX;
        final num deltaY = lastY - newY;

        dragged.scrollLeft += deltaX.round();
        dragged.scrollTop += deltaY.round();

        lastX = newX;
        lastY = newY;

        wasDragged = true;
      }
    });
  }
}
