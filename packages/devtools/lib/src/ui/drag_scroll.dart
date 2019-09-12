// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:html_shim/html.dart';

import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';

class DragScroll {
  /// Whether the element was dragged on the previous click or touch.
  bool wasDragged = false;

  // This callback can optionally be set to perform additional actions on a
  // vertical scroll. For example, the CPU flame chart sets this callback to
  // force a canvas rebuild on vertical scroll.
  VoidCallback _onVerticalScroll;

  set onVerticalScroll(VoidCallback callback) => _onVerticalScroll = callback;

  StreamSubscription<MouseEvent> _mouseMoveListener;

  StreamSubscription<MouseEvent> _mouseUpListener;

  StreamSubscription<TouchEvent> _touchMoveListener;

  StreamSubscription<TouchEvent> _touchEndListener;

  void enableDragScrolling(CoreElement element) {
    final dragged = element.element;
    _handleMouseDrags(dragged);
    _handleTouchDrags(dragged);
  }

  void _handleMouseDrags(Element dragged) {
    num lastX;
    num lastY;

    dragged.onMouseDown.listen((event) {
      final MouseEvent m = event;

      wasDragged = false;
      lastX = m.client.x;
      lastY = m.client.y;

      m.preventDefault();

      _mouseMoveListener = window.onMouseMove.listen((event) {
        final MouseEvent m = event;
        final num newX = m.client.x;
        final num newY = m.client.y;

        final num deltaX = lastX - newX;
        final num deltaY = lastY - newY;

        dragged.scrollLeft += deltaX.round();
        dragged.scrollTop += deltaY.round();

        if (_onVerticalScroll != null && deltaY.round() != 0) {
          _onVerticalScroll();
        }

        lastX = newX;
        lastY = newY;

        wasDragged = true;
      });

      _mouseUpListener = window.onMouseUp.listen((event) {
        _mouseUpListener.cancel();
        _mouseMoveListener.cancel();
      });
    });
  }

  void _handleTouchDrags(Element dragged) {
    num lastX;
    num lastY;

    dragged.onTouchStart.listen((event) {
      final TouchEvent t = event;
      // If there are multiple touches, always use the first.
      final Touch touch = t.touches.first;

      wasDragged = false;
      lastX = touch.client.x;
      lastY = touch.client.y;

      t.preventDefault();

      _touchMoveListener = window.onTouchMove.listen((event) {
        final TouchEvent t = event;
        // If there are multiple touches, always use the first.
        final Touch touch = t.touches.first;

        final num newX = touch.client.x;
        final num newY = touch.client.y;

        final num deltaX = lastX - newX;
        final num deltaY = lastY - newY;

        dragged.scrollLeft += deltaX.round();
        dragged.scrollTop += deltaY.round();

        if (_onVerticalScroll != null && deltaY.round() != 0) {
          _onVerticalScroll();
        }

        lastX = newX;
        lastY = newY;

        wasDragged = true;
      });

      _touchEndListener = window.onTouchEnd.listen((event) {
        final TouchEvent t = event;
        if (t.touches.isEmpty) {
          _touchEndListener.cancel();
          _touchMoveListener.cancel();
        }
      });
    });
  }
}
