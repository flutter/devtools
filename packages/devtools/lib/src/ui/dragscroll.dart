// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import '../ui/elements.dart';

void listenForDragScrolling(CoreElement element) {
  final dragged = element.element;

  num lastX;
  num lastY;
  bool clicked = false;

  dragged.addEventListener(
    'mousedown',
        (event) {
      final MouseEvent m = event;
      clicked = true;
      lastX = m.client.x;
      lastY = m.client.y;

      // TODO(kenzie): once flame chart items are clickable, we will need to
      // tweak this logic to differentiate between clicks and click-drags.
      m.preventDefault();
    },
    false,
  );

  window.addEventListener(
    'mouseup',
        (event) => clicked = false,
    false,
  );

  window.addEventListener(
    'mousemove',
        (event) {
      final MouseEvent m = event;
      if (clicked) {
        final num newX = m.client.x;
        final num newY = m.client.y;

        final deltaX = lastX - newX;
        final deltaY = lastY - newY;

        dragged.scrollLeft += deltaX;
        dragged.scrollTop += deltaY;

        lastX = newX;
        lastY = newY;
      }
    },
    false,
  );
}
