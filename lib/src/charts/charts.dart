// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' show Element, window, Rectangle, Event;
import 'dart:math' as math;

import '../framework/framework.dart';
import '../ui/elements.dart';

abstract class LineChart<T> {
  LineChart(this.parent, {String classes}) {
    parent.element.style.position = 'relative';

    _windowResizeSubscription =
        window.onResize.listen((Event e) => _updateSize());
    Timer.run(_updateSize);

    chartElement = parent.add(div(c: classes)
      ..layoutVertical()
      ..flex());

    chartElement.setInnerHtml('''
<svg viewBox="0 0 500 $fixedHeight">
<polyline fill="none" stroke="#0074d9" stroke-width="2" points=""/>
</svg>
''');
  }

  // These charts are currently fixed at 98px high (100px less a top and bottom
  // 1px border).
  static const int fixedHeight = 98;

  StreamSubscription<Event> _windowResizeSubscription;

  final CoreElement parent;
  CoreElement chartElement;
  math.Point<int> dim;

  final SetStateMixin _state = SetStateMixin();
  T data;

  void _updateSize() {
    if (!isMounted) {
      return;
    }

    final Rectangle<num> rect = chartElement.element.getBoundingClientRect();
    if (rect.width == 0 || rect.height == 0) {
      return;
    }

    final Element svgChild = chartElement.element.children.first;
    svgChild.setAttribute('viewBox', '0 0 ${rect.width} $fixedHeight');
    dim = math.Point<int>(rect.width.toInt(), rect.height.toInt());

    if (data != null) {
      _state.setState(() {
        update(data);
      });
    }
  }

  set disabled(bool value) {
    parent.disabled = value;
  }

  void updateFrom(T data) {
    this.data = data;
    update(data);
  }

  void update(T data);

  bool get isMounted {
    return chartElement.element.parent != null;
  }

  void dispose() {
    _windowResizeSubscription?.cancel();
  }
}
