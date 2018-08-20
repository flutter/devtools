// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' show Element, window, Rectangle, Event;
import 'dart:math' as math;

import '../framework/framework.dart';
import '../ui/elements.dart';

abstract class LineChart<T> {
  final CoreElement parent;
  CoreElement chartElement;
  math.Point<int> dim;

  final SetStateMixin _state = new SetStateMixin();
  T data;

  LineChart(this.parent) {
    parent.element.style.position = 'relative';

    window.onResize.listen((Event e) => _updateSize());
    Timer.run(_updateSize);

    chartElement = parent.add(div()
      ..layoutVertical()
      ..flex());

    chartElement.setInnerHtml('''
<svg viewBox="0 0 500 100">
<polyline fill="none" stroke="#0074d9" stroke-width="2" points=""/>
</svg>
''');
  }

  void _updateSize() {
    if (!isMounted) {
      return;
    }

    final Rectangle<num> rect = chartElement.element.getBoundingClientRect();
    if (rect.width == 0 || rect.height == 0) {
      return;
    }

    final Element svgChild = chartElement.element.children.first;
    svgChild.setAttribute('viewBox', '0 0 ${rect.width} ${rect.height}');
    dim = new math.Point<int>(rect.width.toInt(), rect.height.toInt());

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
}
