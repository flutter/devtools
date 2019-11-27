// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:html_shim/html.dart';
import 'package:meta/meta.dart';

import '../timeline/timeline_model.dart';
import '../ui/colors.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/html_drag_scroll.dart';
import '../ui/html_elements.dart';
import '../ui/theme.dart';
import '../ui/viewport_canvas.dart';
import '../utils.dart';

// TODO(kenz): add tooltips to nodes on hover.

// We use the same color in light and dark mode because it aligns well with both
// color schemes.
const _selectedNodeColor = ThemedColor(
  mainUiColorSelectedLight,
  mainUiColorSelectedLight,
);

const _shadedBackgroundColor =
    ThemedColor(Color(0xFFF6F6F6), Color(0xFF2D2E31));

const double fontSize = 14.0;
const double _textOffsetY = 18.0;
const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double topOffset = rowHeightWithPadding;
const double sideInset = 70.0;

List<num> _asciiMeasurements;

abstract class FlameChart<T> {
  FlameChart({
    @required this.data,
    @required this.duration,
    @required this.width,
    @required this.height,
    @required this.startInset,
  })  : totalStartingWidth = width - startInset - sideInset,
        timelineGrid = TimelineGrid(duration, width, startInset) {
    initUiElements();
  }

  final T data;

  final Duration duration;

  final double startInset;

  final double totalStartingWidth;

  // These values are not final because the flame chart viewport can change in
  // size.
  double width;
  double height;

  double get calculatedWidthWithInsets =>
      calculatedWidth + startInset + sideInset;

  final _nodeSelectedController = StreamController<FlameChartNode>.broadcast();

  Stream<FlameChartNode> get onNodeSelected => _nodeSelectedController.stream;

  FlameChartNode selectedNode;

  final List<FlameChartRow> rows = [];

  final List<FlameChartSection> sections = [];

  TimelineGrid timelineGrid;

  num zoomLevel = 1;

  num get zoomMultiplier => zoomLevel * 0.003;

  // The DOM doesn't allow floating point scroll offsets so we track a
  // theoretical floating point scroll offset corresponding to the current
  // scroll offset to reduce floating point error when zooming.
  num floatingPointScrollLeft = 0;

  @mustCallSuper
  void initUiElements() {
    rows.clear();
    sections.clear();
  }

  double get calculatedWidth;

  void expandRows(int newRowLength) {
    final currentLength = rows.length;
    for (int i = currentLength; i < newRowLength; i++) {
      rows.add(FlameChartRow());
    }
  }

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

    // TODO(kenz): consolidate binary search logic into geometry helper.
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

  FlameChartNode sectionLabel(
    String title,
    Color backgroundColor, {
    @required double top,
    @required double width,
  }) {
    return FlameChartNode<TimelineEvent>(
      Rect.fromLTRB(rowPadding, top, width, top + rowHeight),
      backgroundColor,
      title == 'GPU' ? Colors.white : Colors.black,
      Colors.black,
      null,
      (_) => title,
      startInset,
    );
  }
}

abstract class FlameChartCanvas<T> extends FlameChart {
  FlameChartCanvas({
    @required T data,
    @required Duration duration,
    @required double width,
    @required double height,
    double startInset = sideInset,
    String classes,
    int maxZoomLevel = 150,
  })  : _maxZoomLevel = maxZoomLevel,
        super(
          data: data,
          duration: duration,
          width: width,
          height: height,
          startInset: startInset,
        ) {
    _viewportCanvas = ViewportCanvas(
      paintCallback: paintCallback,
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

  final HtmlDragScroll _dragScroll = HtmlDragScroll();

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
  final int _maxZoomLevel;
  final _minZoomLevel = 1;

  void _initAsciiMeasurements() {
    // We have already initialized the list of Ascii measurements.
    if (_asciiMeasurements != null) return;

    final measurementCanvas = CanvasElement().context2D
      ..font = fontStyleToCss(const TextStyle(fontSize: fontSize));
    _asciiMeasurements = List.generate(
      128,
      (i) => measurementCanvas.measureText(ascii.decode([i])).width,
    );
  }

  // TODO(kenz): optimize painting to canvas by grouping paints with the same
  // canvas settings.
  void paintCallback(CanvasRenderingContext2D canvas, Rect visible) {
    paintSections(canvas, visible);
    paintRows(canvas, visible);
    paintTimelineGrid(canvas, visible);
  }

  void paintSections(CanvasRenderingContext2D canvas, Rect visible) {
    final oddSections = sections.where((s) => s.index % 2 == 1).toList();
    for (FlameChartSection section in oddSections) {
      canvas
        ..fillStyle = colorToCss(_shadedBackgroundColor)
        ..fillRect(
          visible.left,
          section.absStartY,
          visible.width,
          math.min(
              visible.bottom,
              (section.endRow - section.startRow) * rowHeightWithPadding +
                  sectionSpacing),
        );
    }
  }

  void paintRows(CanvasRenderingContext2D canvas, Rect visible) {
    final int startRow = math.max(rowIndexForY(visible.top), 0);
    final int endRow = math.min(
      rowIndexForY(visible.bottom) + 1,
      rows.length,
    );
    for (int i = startRow; i < endRow; i++) {
      paintRow(canvas, i, visible);
    }
  }

  void paintTimelineGrid(CanvasRenderingContext2D canvas, Rect visible) {
    timelineGrid.paint(canvas, _viewportCanvas.viewport, visible);
  }

  void paintRow(
    CanvasRenderingContext2D canvas,
    int index,
    Rect visible,
  ) {
    final row = rows[index];
    // TODO(kenz): use binary search technique here.
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
    num newZoomLevel = zoomLevel + deltaY * zoomMultiplier;
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
    final num fixedX = mouseX + lastScrollLeft - startInset;
    // Calculate and set our new horizontal scroll position.
    if (fixedX >= 0) {
      floatingPointScrollLeft =
          fixedX * newZoomLevel / zoomLevel + startInset - mouseX;
    } else {
      // No need to transform as we are in the fixed portion of the window.
      floatingPointScrollLeft = lastScrollLeft;
    }
    zoomLevel = newZoomLevel;

    updateChartForZoom();
  }

  void updateChartForZoom() {
    updateNodesForZoom();
    timelineGrid.updateForZoom(zoomLevel, calculatedWidth);
    rebuildAndPositionAfterZoom();
  }

  void updateNodesForZoom() {
    for (FlameChartRow row in rows) {
      for (FlameChartNode node in row.nodes) {
        node.updateForZoom(zoom: zoomLevel);
      }
    }
  }

  void rebuildAndPositionAfterZoom() {
    forceRebuildForSize(calculatedWidthWithInsets, height);
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
  final List<FlameChartNode> nodes = [];
}

class FlameChartSection {
  FlameChartSection(
    this.index, {
    @required this.startRow,
    @required this.endRow,
    this.absStartY,
  });

  final int index;

  /// Start row (inclusive) for this section.
  final int startRow;

  /// End row (exclusive) for this section.
  final int endRow;

  double absStartY;
}

class FlameChartNode<T> {
  FlameChartNode(
    this.rect,
    this.backgroundColor,
    this.textColor,
    this.selectedTextColor,
    this.data,
    this.displayTextProvider,
    this.chartStartInset, {
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

  static const minWidthForText = 20.0;

  /// Left value for the flame chart item at zoom level 1.
  final num startingLeft;

  /// Width value for the flame chart item at zoom level 1;
  final num startingWidth;

  final Color backgroundColor;

  final Color textColor;

  final Color selectedTextColor;

  final T data;

  final String Function(T) displayTextProvider;

  final double chartStartInset;

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
        ..font = fontStyleToCss(const TextStyle(fontSize: fontSize));

      String displayText = text;

      // TODO(kenz): further optimize text painting by setting a budget for
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
    // If the node has no data, it is a label and its zoom should not change.
    if (data == null) return;

    // TODO(kenz): this comment may be dated now that we are drawing to
    // canvas. Look into it and delete it if necessary.
    // Do not round these values. Rounding the left could cause us to have
    // inaccurately placed events on the chart. Rounding the width could cause
    // us to lose very small events if the width rounds to zero.
    final newLeft = (startingLeft - chartStartInset) * zoom + chartStartInset;
    final newWidth = startingWidth * zoom;

    final updatedRect = Rect.fromLTWH(newLeft, rect.top, newWidth, rect.height);
    rect = updatedRect;
  }
}

class TimelineGrid {
  TimelineGrid(this._duration, this._flameChartWidth, this._chartStartInset);

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

  final double _chartStartInset;

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

    double left;
    if (visible.left == 0.0) {
      left = _chartStartInset;
    } else {
      left = (visible.left - _chartStartInset) ~/
              currentInterval *
              currentInterval +
          _chartStartInset;
    }

    final firstGridNodeText = msText(
      const Duration(microseconds: 0),
      fractionDigits: 1,
    );

    // Set canvas styles and handle the first grid node since it will have a
    // different width than the rest.
    canvas
      ..font = fontStyleToCss(const TextStyle(fontSize: fontSize))
      ..fillStyle = colorToCss(timestampColor)
      ..fillText(
        firstGridNodeText,
        _timestampLeft(firstGridNodeText, 0, _chartStartInset, canvas),
        viewport.top + _textOffsetY,
      )
      ..strokeStyle = colorToCss(gridLineColor)
      ..lineWidth = gridLineWidth
      ..beginPath()
      ..moveTo(_chartStartInset, visible.top)
      ..lineTo(_chartStartInset, visible.bottom)
      ..closePath()
      ..stroke();

    while (left < visible.right) {
      if (left + currentInterval < visible.left || left > visible.right) {
        // We do not need to draw the grid node because it is out of view.
        return;
      }

      // TODO(kenz): Instead of calculating timestamp based on position, track
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
    return ((gridItemEnd - _chartStartInset) /
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
