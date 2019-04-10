// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import '../ui/viewport_canvas.dart';
import '../utils.dart';
import 'cpu_profile_protocol.dart';
import 'frame_flame_chart.dart';
import 'timeline.dart';

// TODO(kenzie): add tooltips to stack frames on hover.

// TODO(kenzie): this should be removed once the cpu flame chart is optimized
// and complete.
const bool showCpuFlameChart = false;

const _selectedFlameChartNodeColor = ThemedColor(
  mainUiColorSelectedLight,
  mainUiColorSelectedDark,
);

const _shadedBackgroundColor =
    ThemedColor(Color(0xFFF6F6F6), Color(0xFF202124));

const _fontSize = 14.0;
const _textOffsetY = 18.0;
const _flameChartTop = rowHeightWithPadding;
const _rowHeight = 25.0;
const _rowPadding = 2.0;
const rowHeightWithPadding = _rowHeight + _rowPadding;

const _flameChartInset = 70;

// TODO(kenzie): move this class to flame_chart.dart once the frame flame chart
// is ported to canvas and the current implementation in flame_chart.dart is
// deleted.
abstract class FlameChart {
  FlameChart({
    @required this.data,
    @required this.flameChartWidth,
    @required this.flameChartHeight,
  }) : timelineGrid = TimelineGrid(data.timeExtentMicros, flameChartWidth) {
    _initRows();
  }

  static const stackFramePadding = 1;

  final CpuProfileData data;
  final double flameChartWidth;
  final double flameChartHeight;

  final _stackFrameSelectedController =
      StreamController<CpuStackFrame>.broadcast();

  Stream<CpuStackFrame> get onStackFrameSelected =>
      _stackFrameSelectedController.stream;

  FlameChartNode selectedNode;

  List<FlameChartRow> rows = [];

  TimelineGrid timelineGrid;

  num zoomLevel = 1;

  num get _zoomMultiplier => zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  int _colorOffset = 0;

  // TODO(kenzie): base colors on categories (Widget, Render, Layer, User code,
  // etc.)
  Color nextColor() {
    final color = uiColorPalette[_colorOffset % uiColorPalette.length];
    _colorOffset++;
    return color;
  }

  void _initRows() {
    for (int i = 0; i < data.cpuProfileRoot.depth; i++) {
      rows.add(FlameChartRow(nodes: [], index: i));
    }

    final totalWidth = flameChartWidth - 2 * _flameChartInset;

    final Map<String, double> stackFrameLefts = {};

    double calculateLeftForStackFrame(CpuStackFrame stackFrame) {
      double left;
      if (stackFrame.parent == null) {
        left = _flameChartInset.toDouble();
      } else {
        final stackFrameIndex = stackFrame.index;
        if (stackFrameIndex == 0) {
          // This is the first child of parent. [left] should equal the left
          // value of [stackFrame]'s parent.
          left = stackFrameLefts[stackFrame.parent.id];
        } else {
          assert(stackFrameIndex != -1);
          // [stackFrame] is not the first child of its parent. [left] should
          // equal the right value of its previous sibling.
          final previous = stackFrame.parent.children[stackFrameIndex - 1];
          left = stackFrameLefts[previous.id] +
              (totalWidth * previous.cpuConsumptionRatio);
        }
      }
      stackFrameLefts[stackFrame.id] = left;
      return left;
    }

    void createChartNodes(CpuStackFrame stackFrame, int row) {
      final double width =
          totalWidth * stackFrame.cpuConsumptionRatio - stackFramePadding;
      final left = calculateLeftForStackFrame(stackFrame);
      final top = (row * rowHeightWithPadding + _flameChartTop).toDouble();

      final node = FlameChartNode(
        Rect.fromLTRB(left, top, left + width, top + _rowHeight),
        nextColor(),
        Colors.black,
        Colors.black,
        stackFrame,
      );

      rows[row].nodes.add(node);

      for (CpuStackFrame child in stackFrame.children) {
        createChartNodes(
          child,
          row + 1,
        );
      }
    }

    createChartNodes(data.cpuProfileRoot, 0);
  }

  void selectNodeAtOffset(Offset offset) {
    final node = getNode(offset);

    // Do nothing if the tap did not occur on any nodes or if the tap was to
    // select the already selected node.
    if (node == null || node == selectedNode) {
      return;
    }

    // Un-select the currently selected node if there is one.
    if (selectedNode != null) {
      selectedNode.selected = false;
    }
    // Select the new selected node.
    node.selected = true;
    selectedNode = node;

    _stackFrameSelectedController.add(node.stackFrame);
  }

  num getFlameChartWidth() {
    return rows[0].nodes[0].rect.right - _flameChartInset;
  }

  FlameChartNode getNode(Offset offset) {
    final int rowIndex = getRowIndexForY(offset.dy);
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return null;
    }
    return getNodeInRow(rowIndex, offset.dx);
  }

  FlameChartNode getNodeInRow(int rowIndex, double x) {
    final row = rows[rowIndex];
    final nodes = row.nodes;

    FlameChartNode binarySearchForNode() {
      int min = 0;
      int max = nodes.length;
      while (min < max) {
        final mid = min + ((max - min) >> 1);
        final node = nodes[mid];
        if (x >= node.rect.left && x <= node.rect.right) {
          return node;
        }
        if (x < node.rect.left) {
          max = mid;
        }
        if (x > node.rect.right) {
          min = mid + 1;
        }
      }
      return null;
    }

    return nodes.isEmpty ? null : binarySearchForNode();
  }

  int getRowIndexForY(double y) {
    if (y < _flameChartTop) {
      return -1;
    }
    return math.max((y - _flameChartTop) ~/ rowHeightWithPadding, 0);
  }
}

class FlameChartCanvas extends FlameChart {
  FlameChartCanvas({
    @required CpuProfileData data,
    @required flameChartWidth,
    @required flameChartHeight,
  }) : super(
          data: data,
          flameChartWidth: flameChartWidth,
          flameChartHeight: flameChartHeight,
        ) {
    _viewportCanvas = ViewportCanvas(
      paintCallback: _paintCallback,
      onTap: _onTap,
      classes: 'ui-details-section cpu-flame-chart',
    )..element.element.style.overflow = 'hidden';

    _viewportCanvas.setContentSize(flameChartWidth, flameChartHeight);

    _dragScroll.enableDragScrolling(_viewportCanvas.element);
    _dragScroll.onVerticalScroll = () {
      _viewportCanvas.rebuild(force: true);
    };

    _viewportCanvas.element.element.onMouseWheel.listen(_handleMouseWheel);
  }

  final DragScroll _dragScroll = DragScroll();

  ViewportCanvas _viewportCanvas;

  CoreElement get element => _viewportCanvas.element;

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

  // TODO(kenzie): optimize painting to canvas by grouping paints with the same
  // canvas settings.
  void _paintCallback(CanvasRenderingContext2D canvas, Rect rect) {
    final int startRow = math.max(getRowIndexForY(rect.top), 0);
    final int endRow = math.min(
      getRowIndexForY(rect.bottom) + 1,
      rows.length - 1,
    );
    for (int i = startRow; i < endRow; i++) {
      paintRow(canvas, i, rect);
    }

    timelineGrid.paint(canvas, _viewportCanvas.viewport, rect);
  }

  void paintRow(
    CanvasRenderingContext2D canvas,
    int index,
    Rect visible,
  ) {
    canvas.save();

    final row = rows[index];
    for (FlameChartNode node in row.nodes) {
      if (node.rect.left + node.rect.width < visible.left) continue;
      if (node.rect.left > visible.right) break;
      node.paint(canvas);
    }

    canvas.restore();
  }

  void _onTap(Offset offset) {
    // Prevent clicks when the chart was being dragged.
    if (!_dragScroll.wasDragged) {
      selectNodeAtOffset(offset);
      _viewportCanvas.rebuild(force: true);
    }
  }

  void _handleMouseWheel(WheelEvent e) {
    e.preventDefault();

    if (e.deltaY.abs() >= e.deltaX.abs()) {
      final mouseX = e.client.x -
          _viewportCanvas.element.element.getBoundingClientRect().left;
      _zoom(e.deltaY, mouseX);
    } else {
      // Manually perform horizontal scrolling.
      _viewportCanvas.element.element.scrollLeft += e.deltaX.round();
    }
  }

  void _zoom(num deltaY, num mouseX) {
    assert(data != null);

    deltaY = deltaY.clamp(-maxScrollWheelDelta, maxScrollWheelDelta);
    num newZoomLevel = zoomLevel + deltaY * _zoomMultiplier;
    newZoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    if (newZoomLevel == zoomLevel) return;
    // Store current scroll values for re-calculating scroll location on zoom.
    num lastScrollLeft = _viewportCanvas.element.element.scrollLeft;
    // Test whether the scroll offset has changed by more than rounding error
    // since the last time an exact scroll offset was calculated.
    if ((floatingPointScrollLeft - lastScrollLeft).abs() < 0.5) {
      lastScrollLeft = floatingPointScrollLeft;
    }
    // Position in the zoomable coordinate space that we want to keep fixed.
    final num fixedX = mouseX + lastScrollLeft - _flameChartInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / zoomLevel + _flameChartInset - mouseX;
    } else {
      // No need to transform as we are in the fixed portion of the window.
      floatingPointScrollLeft = lastScrollLeft;
    }
    zoomLevel = newZoomLevel;

    _updateChartForZoom();
  }

  void _updateChartForZoom() {
    for (FlameChartRow row in rows) {
      for (FlameChartNode node in row.nodes) {
        node.updateForZoom(zoom: zoomLevel);
      }
    }

    timelineGrid.updateForZoom(zoomLevel, getFlameChartWidth());

    _viewportCanvas.setContentSize(
      getFlameChartWidth() + 2 * _flameChartInset,
      flameChartHeight,
    );
    _viewportCanvas.rebuild(force: true);

    _viewportCanvas.element.element.scrollLeft =
        math.max(0, floatingPointScrollLeft.round());
  }
}

/// A row in the tree with all information required to render it.
class FlameChartRow {
  const FlameChartRow({
    @required this.nodes,
    @required this.index,
  });

  final List<FlameChartNode> nodes;
  final int index;
}

// TODO Maybe pass an on selected listener to this so we don't have to pass the data
// object around
class FlameChartNode {
  FlameChartNode(
    this.rect,
    this.backgroundColor,
    this.textColor,
    this.selectedTextColor,
    this.stackFrame,
  )   : startingLeft = rect.left,
        startingWidth = rect.width;

  static const horizontalPadding = 4.0;
  static const borderRadius = 2.0;
  static const selectedBorderWidth = 1.0;
  static const selectedBorderColor = ThemedColor(
    Color(0x5A1B1F23),
    Color(0x5A1B1F23),
  );
  // TODO(kenzie): reassess this max when polishing text painting logic.
  static const maxDisplayTextLength = 20;

  Rect rect;

  /// Left value for the flame chart item at zoom level 1.
  final num startingLeft;

  /// Width value for the flame chart item at zoom level 1;
  final num startingWidth;

  final Color backgroundColor;

  final Color textColor;

  final Color selectedTextColor;

  final CpuStackFrame stackFrame;

  String get text => stackFrame.name;

  String get tooltip => stackFrame.toString();

  bool selected = false;

  void paint(CanvasRenderingContext2D canvas) {
    // Fill a rectangle with a border radius.
    canvas
      ..fillStyle =
          colorToCss(selected ? _selectedFlameChartNodeColor : backgroundColor)
      ..beginPath()
      ..moveTo(rect.left + borderRadius, rect.top)
      ..lineTo(rect.right - borderRadius, rect.top)
      ..quadraticCurveTo(
        rect.right,
        rect.top,
        rect.right,
        rect.top + borderRadius,
      )
      ..lineTo(rect.right, rect.bottom - borderRadius)
      ..quadraticCurveTo(
        rect.right,
        rect.bottom,
        rect.right - borderRadius,
        rect.bottom,
      )
      ..lineTo(rect.left + borderRadius, rect.bottom)
      ..quadraticCurveTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - borderRadius,
      )
      ..lineTo(rect.left, rect.top + borderRadius)
      ..quadraticCurveTo(
        rect.left,
        rect.top,
        rect.left + borderRadius,
        rect.top,
      )
      ..closePath()
      ..fill();

    if (selected) {
      canvas
        ..strokeStyle = colorToCss(selectedBorderColor)
        ..lineWidth = selectedBorderWidth
        ..stroke();
    }

    canvas
      ..fillStyle = colorToCss(textColor)
      ..font = fontStyleToCss(TextStyle(fontSize: _fontSize));

    // TODO(kenzie): polish this. Sometimes we trim excessively. We should do
    // something smarter here to be more exact. 'm' is arbitrary - it was
    // selected after trial and error with different letter measurements.
    final singleLetterWidth = canvas.measureText('m').width;
    final maxLetters = math.min(
      (rect.width - horizontalPadding * 2) ~/ singleLetterWidth,
      selected ? text.length : math.min(text.length, maxDisplayTextLength),
    );

    String displayText = text.substring(0, maxLetters);
    if (maxLetters == maxDisplayTextLength &&
        text.length > maxDisplayTextLength) {
      displayText += '...';
    }

    canvas.fillText(
      displayText,
      rect.left + horizontalPadding,
      rect.top + _textOffsetY,
    );
  }

  void updateForZoom({@required num zoom}) {
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = (startingLeft - _flameChartInset) * zoom + _flameChartInset;
    final newWidth = startingWidth * zoom;

    final updatedRect = Rect.fromLTWH(newLeft, rect.top, newWidth, rect.height);
    rect = updatedRect;
  }
}

class TimelineGrid {
  TimelineGrid(this._duration, this._flameChartWidth);

  static const baseGridInterval = 150;

  /// Frame duration in micros.
  final num _duration;

  num currentInterval = baseGridInterval;

  num _flameChartWidth;

  num _zoomLevel = 1;

  void paint(CanvasRenderingContext2D canvas, Rect viewport, Rect visible) {
    // Draw the first grid item since it will have a different width than the
    // rest.
    final gridItem = TimelineGridNode(
      0,
      _flameChartInset,
      const Duration(microseconds: 0),
    );

    gridItem.paint(canvas, viewport, visible);

    num left =
        (visible.left - _flameChartInset) ~/ currentInterval * currentInterval +
            _flameChartInset;

    while (left < visible.right) {
      // TODO(kenzie): Instead of calculating timestamp based on position, track
      // timestamp var and increment it by time interval represented by each
      // grid item. See comment on https://github.com/flutter/devtools/pull/325.
      final Duration timestamp = Duration(
          microseconds: getTimestampForPosition(left + currentInterval));
      final gridItem = TimelineGridNode(left, currentInterval, timestamp);

      gridItem.paint(canvas, viewport, visible);

      left += currentInterval;
    }
  }

  /// Returns the timestamp rounded to the nearest microsecond for the
  /// x-position.
  int getTimestampForPosition(num gridItemEnd) {
    return ((gridItemEnd - _flameChartInset) / _flameChartWidth * _duration)
        .round();
  }

  void updateForZoom(num newZoomLevel, num newFlameChartWidth) {
    if (_zoomLevel == newZoomLevel) {
      return;
    }

    _flameChartWidth = newFlameChartWidth;

    final log2NewZoomLevel = log2(newZoomLevel);

    final gridZoomFactor = math.pow(2, log2NewZoomLevel);
    final gridIntervalPx = baseGridInterval / gridZoomFactor;

    /// The physical pixel width of the grid interval at [newZoomLevel].
    currentInterval = gridIntervalPx * newZoomLevel;

    _zoomLevel = newZoomLevel;
  }
}

class TimelineGridNode {
  TimelineGridNode(this.currentLeft, this.currentWidth, this.timestamp)
      : timestampText = msText(
          timestamp,
          fractionDigits: timestamp.inMicroseconds == 0 ? 1 : 3,
        );

  final Duration timestamp;
  final num currentLeft;
  final num currentWidth;
  final String timestampText;

  static const gridLineWidth = 0.8;
  static const gridLineColor = Color(0xFFCCCCCC);
  static const timestampOffsetX = 6.0;
  static const timestampColor = ThemedColor(
    Color(0xFF24292E),
    Color(0xFFFAFBFC),
  );

  void paint(CanvasRenderingContext2D canvas, Rect viewport, Rect visible) {
    if (currentLeft + currentWidth < visible.left ||
        currentLeft > visible.right) {
      // We do not need to draw the grid node because it is out of view.
      return;
    }

    // Draw the background for the section that will contain the timestamp. This
    // section will be sticky to the top of the viewport. Make the background
    // rectangles slightly larger than the current width to account for gaps
    // that would be caused by rounding.
    canvas.fillStyle = colorToCss(_shadedBackgroundColor);
    canvas.fillRect(
      currentLeft,
      viewport.top,
      currentWidth + 2,
      _rowHeight,
    );

    // Paint the timestamp. This will be sticky to the top of the viewport.
    canvas.font = fontStyleToCss(TextStyle(fontSize: _fontSize));
    canvas.fillStyle = colorToCss(timestampColor);

    final timestampX = currentLeft +
        currentWidth -
        canvas.measureText(timestampText).width -
        timestampOffsetX;

    canvas.fillText(timestampText, timestampX, viewport.top + _textOffsetY);

    canvas.strokeStyle = colorToCss(gridLineColor);
    canvas.lineWidth = gridLineWidth;

    canvas.beginPath();
    canvas
      ..moveTo(currentLeft + currentWidth, visible.top)
      ..lineTo(currentLeft + currentWidth, visible.bottom)
      ..stroke();
  }
}
