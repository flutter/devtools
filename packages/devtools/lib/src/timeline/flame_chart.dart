// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import 'timeline.dart';

// TODO(kenzie): delete this file once frame_flame_chart is ported to canvas.

const selectedFlameChartItemColor =
    ThemedColor(mainUiColorSelectedLight, mainUiColorSelectedLight);

/// Flame chart superclass that houses zooming, scrolling, and selection logic,
/// among other data handling methods like `update` and `reset`.
///
/// Any subclass of [FlameChart] must override [render] - the method responsible
/// for drawing the flame chart. Additional method overrides may be necessary.
class FlameChart<T> extends CoreElement {
  FlameChart({
    @required Stream<FlameChartItem> onSelectedFlameChartItem,
    @required DragScroll dragScroll,
    String classes,
    this.flameChartInset = 0,
  }) : super('div', classes: classes) {
    flex();
    layoutVertical();

    dragScroll.enableDragScrolling(this);

    element.onMouseWheel.listen(_handleMouseWheel);

    onSelectedFlameChartItem.listen(_selectItem);
  }

  final int flameChartInset;

  static const padding = 2;
  static const int rowHeight = 25;

  /// All flame chart items currently drawn on the chart.
  final List<FlameChartItem> chartItems = [];

  /// Maximum scroll delta allowed for scrollwheel based zooming.
  ///
  /// This isn't really needed but is a reasonable for safety in case we
  /// aren't handling some mouse based scroll wheel behavior well, etc.
  final num maxScrollWheelDelta = 20;

  /// Maximum zoom level we should allow.
  ///
  /// Arbitrary large number to accommodate spacing for some of the shortest
  /// events when zoomed in to [_maxZoomLevel].
  final _maxZoomLevel = 150;
  final _minZoomLevel = 1;
  num zoomLevel = 1;

  num get _zoomMultiplier => zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  FlameChartItem selectedItem;

  T data;

  /// Method responsible for drawing the flame chart.
  ///
  /// This method is REQUIRED to be overridden by a subclass - otherwise, the
  /// chart will be blank.
  void render() {}

  void update(T _data) {
    data = _data;
    reset();

    if (_data != null) {
      render();
    }
  }

  void reset() {
    clear();
    element.scrollLeft = 0;
    element.scrollTop = 0;
    zoomLevel = 1;
    chartItems.clear();
  }

  void addItemToFlameChart(FlameChartItem item, CoreElement container) {
    chartItems.add(item);
    container.element.append(item.element);
  }

  num getFlameChartWidth() {
    num maxRight = 0;
    for (FlameChartItem item in chartItems) {
      if ((item.currentLeft + item.currentWidth) > maxRight) {
        maxRight = item.currentLeft + item.currentWidth;
      }
    }
    // Subtract [beginningInset] to account for spacing at the beginning of the
    // chart.
    return maxRight - flameChartInset;
  }

  void _selectItem(FlameChartItem item) {
    // Unselect the previously selected item.
    selectedItem?.setSelected(false);

    // Select the new item.
    item.setSelected(true);
    selectedItem = item;
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() >= e.deltaX.abs()) {
      final mouseX = e.client.x - element.getBoundingClientRect().left;
      _zoom(e.deltaY, mouseX);
    } else {
      // Manually perform horizontal scrolling.
      element.scrollLeft += e.deltaX.round();
    }
  }

  void _zoom(num deltaY, num mouseX) {
    assert(data != null);

    deltaY = deltaY.clamp(-maxScrollWheelDelta, maxScrollWheelDelta);
    num newZoomLevel = zoomLevel + deltaY * _zoomMultiplier;
    newZoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    if (newZoomLevel == zoomLevel) return;
    // Store current scroll values for re-calculating scroll location on zoom.
    num lastScrollLeft = element.scrollLeft;
    // Test whether the scroll offset has changed by more than rounding error
    // since the last time an exact scroll offset was calculated.
    if ((floatingPointScrollLeft - lastScrollLeft).abs() < 0.5) {
      lastScrollLeft = floatingPointScrollLeft;
    }
    // Position in the zoomable coordinate space that we want to keep fixed.
    final num fixedX = mouseX + lastScrollLeft - flameChartInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / zoomLevel + flameChartInset - mouseX;
    } else {
      // No need to transform as we are in the fixed portion of the window.
      floatingPointScrollLeft = lastScrollLeft;
    }
    zoomLevel = newZoomLevel;

    updateChartForZoom();
  }

  void updateChartForZoom() {
    for (FlameChartItem item in chartItems) {
      item.updateHorizontalPosition(zoom: zoomLevel);
    }
  }
}

class FlameChartItem {
  FlameChartItem({
    @required this.startingLeft,
    @required this.startingWidth,
    @required this.top,
    @required this.backgroundColor,
    @required this.defaultTextColor,
    @required this.selectedTextColor,
    this.flameChartInset = 0,
  }) {
    element = Element.div()..className = 'flame-chart-item';
    _labelWrapper = Element.div()..className = 'flame-chart-item-label-wrapper';

    itemLabel = Element.span()
      ..className = 'flame-chart-item-label'
      ..style.color = colorToCss(defaultTextColor);
    _labelWrapper.append(itemLabel);
    element.append(_labelWrapper);

    element.style
      ..background = colorToCss(backgroundColor)
      ..top = '${top}px';
    updateHorizontalPosition(zoom: 1);

    setText();
    setOnClick();
  }

  /// Pixels of padding to place on the right side of the label to ensure label
  /// text does not get too close to the right hand size of each div.
  static const labelPaddingRight = 4;

  static const selectedBorderColor = ThemedColor(
    Color(0x5A1B1F23),
    Color(0x5A1B1F23),
  );

  /// Left value for the flame chart item at zoom level 1.
  final num startingLeft;

  /// Width value for the flame chart item at zoom level 1;
  final num startingWidth;

  /// Top position for the flame chart item.
  final num top;

  final Color backgroundColor;

  final Color defaultTextColor;

  final Color selectedTextColor;

  /// Inset for the start/end of the flame chart.
  final int flameChartInset;

  Element element;
  Element itemLabel;
  Element _labelWrapper;

  num currentLeft;
  num currentWidth;

  // This method should be overridden by the subclass.
  void setText() {}

  // TODO(kenzie): set a global click listener instead of setting one per item.
  // This method should be overridden by the subclass.
  void setOnClick() {}

  void updateHorizontalPosition({@required num zoom}) {
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = flameChartInset + startingLeft * zoom;
    final newWidth = startingWidth * zoom;

    element.style.left = '${newLeft}px';
    if (startingWidth != null) {
      element.style.width = '${newWidth}px';
      _labelWrapper.style.maxWidth =
          '${math.max(0, newWidth - labelPaddingRight)}px';
    }
    currentLeft = newLeft;
    currentWidth = newWidth;
  }

  void setSelected(bool selected) {
    element.style
      ..backgroundColor =
          colorToCss(selected ? selectedFlameChartItemColor : backgroundColor)
      ..border = selected ? '1px solid' : 'none'
      ..borderColor = colorToCss(selectedBorderColor);
    itemLabel.style.color =
        colorToCss(selected ? selectedTextColor : defaultTextColor);
  }
}
