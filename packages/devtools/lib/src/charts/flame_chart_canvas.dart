// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ui/colors.dart';
import '../ui/drag_scroll.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import '../ui/viewport_canvas.dart';
import '../utils.dart';

// TODO(kenzie): add tooltips to nodes on hover.

// We use the same color in light and dark mode because it aligns well with both
// color schemes.
const _selectedNodeColor = ThemedColor(
  mainUiColorSelectedLight,
  mainUiColorSelectedLight,
);

const _shadedBackgroundColor =
    ThemedColor(Color(0xFFF6F6F6), Color(0xFF202124));

const double _fontSize = 14.0;
const double _textOffsetY = 18.0;
const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double topOffset = rowHeightWithPadding;
const double sideInset = 70.0;

List<num> _asciiMeasurements;

abstract class FlameChart<T> {
  FlameChart({
    @required this.data,
    @required this.duration,
    @required this.width,
    @required this.height,
  }) : timelineGrid = TimelineGrid(duration, width) {
    initRows();
  }

  final T data;

  final Duration duration;

  // These values are not final because the flame chart viewport can change in
  // size.
  double width;
  double height;

  double get widthWithInsets => calculatedWidth + 2 * sideInset;

  final _nodeSelectedController = StreamController<FlameChartNode>.broadcast();

  Stream<FlameChartNode> get onNodeSelected => _nodeSelectedController.stream;

  FlameChartNode selectedNode;

  List<FlameChartRow> rows = [];

  TimelineGrid timelineGrid;

  num zoomLevel = 1;

  num get _zoomMultiplier => zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  void initRows();

  double get calculatedWidth;

  void selectNodeAtOffset(Offset offset) {
    final node = nodeAtOffset(offset);

    // Do nothing if the tap did not occur on any nodes, if the tap was to
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

    _nodeSelectedController.add(node);
  }

  FlameChartNode nodeAtOffset(Offset offset) {
    final int rowIndex = rowIndexForY(offset.dy);
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return null;
    }
    return nodeInRow(rowIndex, offset.dx);
  }

  FlameChartNode nodeInRow(int rowIndex, double x) {
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

  double relativeYPosition(double absoluteY) => absoluteY - topOffset;

  int rowIndexForY(double y) {
    if (y < topOffset) {
      return -1;
    }
    return math.max((relativeYPosition(y)) ~/ rowHeightWithPadding, 0);
  }
}

abstract class FlameChartCanvas<T> extends FlameChart {
  FlameChartCanvas({
    @required T data,
    @required Duration duration,
    @required width,
    @required height,
    String classes,
  }) : super(
          data: data,
          duration: duration,
          width: width,
          height: height,
        ) {
    _viewportCanvas = ViewportCanvas(
      paintCallback: _paintCallback,
      onTap: _onTap,
      classes: 'fill-section $classes',
    )..element.element.style.overflow = 'hidden';

    _viewportCanvas.setContentSize(width, height);

    _dragScroll.enableDragScrolling(_viewportCanvas.element);
    _dragScroll.onVerticalScroll = () {
      _viewportCanvas.rebuild(force: true);
    };

    _viewportCanvas.element.element.onMouseWheel.listen(_handleMouseWheel);

    _initAsciiMeasurements();
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

  void _initAsciiMeasurements() {
    // We have already initialized the list of Ascii measurements.
    if (_asciiMeasurements != null) return;

    final measurementCanvas = CanvasElement().context2D
      ..font = fontStyleToCss(const TextStyle(fontSize: _fontSize));
    _asciiMeasurements = List.generate(
      128,
      (i) => measurementCanvas.measureText(ascii.decode([i])).width,
    );
  }

  // TODO(kenzie): optimize painting to canvas by grouping paints with the same
  // canvas settings.
  void _paintCallback(CanvasRenderingContext2D canvas, Rect rect) {
    final int startRow = math.max(rowIndexForY(rect.top), 0);
    final int endRow = math.min(
      rowIndexForY(rect.bottom) + 1,
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
    final row = rows[index];
    for (FlameChartNode node in row.nodes) {
      if (node.rect.left + node.rect.width < visible.left) continue;
      if (node.rect.left > visible.right) break;
      node.paint(canvas);
    }
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
    final num fixedX = mouseX + lastScrollLeft - sideInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / zoomLevel + sideInset - mouseX;
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

    timelineGrid.updateForZoom(zoomLevel, calculatedWidth);

    forceRebuildForSize(widthWithInsets, height);

    _viewportCanvas.element.element.scrollLeft =
        math.max(0, floatingPointScrollLeft.round());
  }

  void forceRebuildForSize(double width, double height) {
    this.width = width;
    this.height = height;

    _viewportCanvas.setContentSize(width, height);
    _viewportCanvas.rebuild(force: true);
  }
}

class FlameChartRow {
  const FlameChartRow({
    @required this.nodes,
    @required this.index,
  });

  final List<FlameChartNode> nodes;
  final int index;
}

class FlameChartNode<T> {
  FlameChartNode(
    this.rect,
    this.backgroundColor,
    this.textColor,
    this.selectedTextColor,
    this.data,
    this.displayTextProvider, {
    this.rounded = false,
  })  : startingLeft = rect.left,
        startingWidth = rect.width;

  static const horizontalPadding = 4.0;
  static const borderRadius = 2.0;
  static const selectedBorderWidth = 1.0;
  static const selectedBorderColor = ThemedColor(
    Color(0x5A1B1F23),
    Color(0x5A1B1F23),
  );

  static const minWidthForText = 20;

  /// Left value for the flame chart item at zoom level 1.
  final num startingLeft;

  /// Width value for the flame chart item at zoom level 1;
  final num startingWidth;

  final Color backgroundColor;

  final Color textColor;

  final Color selectedTextColor;

  final T data;

  final String Function(T) displayTextProvider;

  final bool rounded;

  final Map<String, num> textMeasurements = {};

  Rect rect;

  String get text => displayTextProvider(data);

  String get tooltip => '$data';

  num get maxTextWidth => rect.width - horizontalPadding * 2;

  bool selected = false;

  void paint(CanvasRenderingContext2D canvas) {
    canvas.fillStyle =
        colorToCss(selected ? _selectedNodeColor : backgroundColor);

    if (rounded) {
      canvas
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
    } else {
      canvas.fillRect(rect.left, rect.top, rect.width, rect.height);
    }

    if (selected) {
      canvas
        ..strokeStyle = colorToCss(selectedBorderColor)
        ..lineWidth = selectedBorderWidth
        ..stroke();
    }

    if (rect.width > minWidthForText) {
      canvas
        ..fillStyle = colorToCss(selected ? selectedTextColor : textColor)
        ..font = fontStyleToCss(const TextStyle(fontSize: _fontSize));

      String displayText = text;

      // TODO(kenzie): further optimize text painting by setting a budget for
      // how much text can be measured each frame, and incrementally updating
      // the text in the UI.
      if (!_textFitsInRect(displayText, canvas)) {
        displayText = longestFittingSubstring(
          text,
          maxTextWidth,
          _asciiMeasurements,
          (int value) => canvas.measureText(String.fromCharCode(value)).width,
        );
      }

      canvas.fillText(
        displayText,
        rect.left + horizontalPadding,
        rect.top + _textOffsetY,
        maxTextWidth,
      );
    }
  }

  bool _textFitsInRect(String text, CanvasRenderingContext2D canvas) {
    final textWidth = textMeasurements[text] ??= canvas.measureText(text).width;
    return textWidth <= maxTextWidth;
  }

  void updateForZoom({@required num zoom}) {
    // TODO(kenzie): this comment may be dated now that we are drawing to
    // canvas. Look into it and delete it if necessary.
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = (startingLeft - sideInset) * zoom + sideInset;
    final newWidth = startingWidth * zoom;

    final updatedRect = Rect.fromLTWH(newLeft, rect.top, newWidth, rect.height);
    rect = updatedRect;
  }
}

class TimelineGrid {
  TimelineGrid(this._duration, this._flameChartWidth);

  static const baseGridIntervalPx = 150;
  static const gridLineWidth = 0.4;
  static const gridLineColor = ThemedColor(
    Color(0xFFCCCCCC),
    Color(0xFF585858),
  );
  static const timestampOffsetX = 6.0;
  static const timestampColor = ThemedColor(
    Color(0xFF24292E),
    Color(0xFFFAFBFC),
  );

  final Duration _duration;

  num currentInterval = baseGridIntervalPx;

  num _flameChartWidth;

  num _zoomLevel = 1;

  void paint(CanvasRenderingContext2D canvas, Rect viewport, Rect visible) {
    // Draw the background for the section that will contain the timestamps.
    // This section will be sticky to the top of the viewport.
    canvas.fillStyle = colorToCss(_shadedBackgroundColor);
    canvas.fillRect(
      visible.left,
      viewport.top,
      visible.width,
      rowHeight,
    );

    num left = (visible.left - sideInset) ~/ currentInterval * currentInterval +
        sideInset;

    final firstGridNodeText = msText(
      const Duration(microseconds: 0),
      fractionDigits: 1,
    );

    // Set canvas styles and handle the first grid node since it will have a
    // different width than the rest.
    canvas
      ..font = fontStyleToCss(const TextStyle(fontSize: _fontSize))
      ..fillStyle = colorToCss(timestampColor)
      ..fillText(
        firstGridNodeText,
        _timestampLeft(firstGridNodeText, 0, sideInset, canvas),
        viewport.top + _textOffsetY,
      )
      ..strokeStyle = colorToCss(gridLineColor)
      ..lineWidth = gridLineWidth
      ..beginPath()
      ..moveTo(sideInset, visible.top)
      ..lineTo(sideInset, visible.bottom)
      ..closePath()
      ..stroke();

    while (left < visible.right) {
      if (left + currentInterval < visible.left || left > visible.right) {
        // We do not need to draw the grid node because it is out of view.
        return;
      }

      // TODO(kenzie): Instead of calculating timestamp based on position, track
      // timestamp var and increment it by time interval represented by each
      // grid item. See comment on https://github.com/flutter/devtools/pull/325.
      final timestamp =
          Duration(microseconds: timestampForPosition(left + currentInterval));

      final timestampText = msText(
        timestamp,
        fractionDigits: timestamp.inMicroseconds == 0 ? 1 : 3,
      );

      final timestampX = _timestampLeft(
        timestampText,
        left,
        currentInterval,
        canvas,
      );

      // Paint the timestamps and compute the line to stroke for the grid lines.
      canvas
        ..fillText(timestampText, timestampX, viewport.top + _textOffsetY)
        ..beginPath()
        ..moveTo(left + currentInterval, viewport.top)
        ..lineTo(left + currentInterval, viewport.bottom)
        ..closePath()
        ..stroke();

      left += currentInterval;
    }
  }

  num _timestampLeft(
    String timestampText,
    num left,
    num width,
    CanvasRenderingContext2D canvas,
  ) {
    return left +
        width -
        canvas.measureText(timestampText).width -
        timestampOffsetX;
  }

  /// Returns the timestamp rounded to the nearest microsecond for the
  /// x-position.
  int timestampForPosition(num gridItemEnd) {
    return ((gridItemEnd - sideInset) /
            _flameChartWidth *
            _duration.inMicroseconds)
        .round();
  }

  void updateForZoom(num newZoomLevel, num newFlameChartWidth) {
    if (_zoomLevel == newZoomLevel) {
      return;
    }

    _flameChartWidth = newFlameChartWidth;

    final log2NewZoomLevel = log2(newZoomLevel);

    final gridZoomFactor = math.pow(2, log2NewZoomLevel);
    final gridIntervalPx = baseGridIntervalPx / gridZoomFactor;

    /// The physical pixel width of the grid interval at [newZoomLevel].
    currentInterval = gridIntervalPx * newZoomLevel;

    _zoomLevel = newZoomLevel;
  }
}
