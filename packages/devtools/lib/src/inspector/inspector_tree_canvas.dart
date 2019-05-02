// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import 'dart:math' as math;
import 'dart:math';

import 'package:meta/meta.dart';

import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/html_icon_renderer.dart';
import '../ui/icons.dart';
import '../ui/viewport_canvas.dart';
import 'inspector_service.dart';
import 'inspector_tree.dart';
import 'inspector_tree_web.dart';

typedef CanvasPaintCallback = void Function(
  CanvasRenderingContext2D canvas,
  int index,
  double width,
  double height,
);

abstract class CanvasPaintEntry extends PaintEntry {
  CanvasPaintEntry(this.x);

  final double x;
  double get right;

  void paint(CanvasRenderingContext2D canvas);
}

class IconPaintEntry extends CanvasPaintEntry {
  IconPaintEntry({
    @required double x,
    @required this.iconRenderer,
  }) : super(x);

  @override
  Icon get icon => iconRenderer.icon;

  final HtmlIconRenderer iconRenderer;

  @override
  void paint(CanvasRenderingContext2D canvas) {
    final image = iconRenderer.image;
    if (image != null) {
      canvas.drawImageScaled(
        image,
        x,
        (rowHeight - iconRenderer.iconHeight) / 2,
        iconRenderer.iconWidth,
        iconRenderer.iconHeight,
      );
    }
  }

  @override
  double get right => x + icon.iconWidth;

  @override
  void attach(InspectorTree owner) {
    final image = iconRenderer.image;
    if (image == null) {
      iconRenderer.loadImage().then((_) {
        // TODO(jacobr): only repaint what is needed.
        owner.setState(() {});
      });
    }
  }
}

class TextPaintEntry extends CanvasPaintEntry {
  TextPaintEntry({
    @required double x,
    @required this.width,
    @required this.text,
    @required this.color,
    @required this.font,
  }) : super(x);

  final double width;
  final String text;
  final String color;
  final String font;

  @override
  Icon get icon => null;

  @override
  void paint(CanvasRenderingContext2D canvas) {
    if (color != null) {
      canvas.fillStyle = color;
    }
    if (font != null) {
      canvas.font = font;
    }
    canvas.fillText(text, x, rowHeight - 7);
  }

  @override
  double get right => x + width;
}

class InspectorTreeNodeRenderCanvasBuilder
    extends InspectorTreeNodeRenderBuilder<InspectorTreeNodeCanvasRender> {
  InspectorTreeNodeRenderCanvasBuilder({
    @required DiagnosticLevel level,
    @required DiagnosticsTreeStyle treeStyle,
  }) : super(level: level, treeStyle: treeStyle);

  double x = 0;
  TextStyle lastStyle;
  String font;
  String color;
  final List<CanvasPaintEntry> _entries = [];
  static final CanvasRenderingContext2D _measurementCanvas =
      CanvasElement(width: 1, height: 1).context2D;

  @override
  void appendText(String text, TextStyle textStyle) {
    if (text == null || text.isEmpty) {
      return;
    }
    if (textStyle != lastStyle) {
      if (textStyle.color != lastStyle?.color) {
        color = colorToCss(textStyle.color);
      }
      font = fontStyleToCss(textStyle);
      lastStyle = textStyle;
      _measurementCanvas.font = font;
    }
    final double width = _measurementCanvas.measureText(text).width;

    _entries.add(TextPaintEntry(
        x: x, width: width, text: text, color: color, font: font));
    x += width;
  }

  @override
  void addIcon(Icon icon) {
    final double width = icon.iconWidth + iconPadding;
    _entries.add(IconPaintEntry(x: x, iconRenderer: getIconRenderer(icon)));
    x += width;
  }

  @override
  InspectorTreeNodeCanvasRender build() {
    return InspectorTreeNodeCanvasRender(_entries, Size(x, rowHeight));
  }
}

class InspectorTreeNodeCanvasRender
    extends InspectorTreeNodeRender<CanvasPaintEntry> {
  InspectorTreeNodeCanvasRender(List<CanvasPaintEntry> entries, Size size)
      : super(entries, size);

  void paint(CanvasRenderingContext2D context, Rect visible) {
    for (var entry in entries) {
      if (entry.x + offset.dx > visible.right) {
        return;
      }
      if (entry.right + offset.dx >= visible.left) {
        entry.paint(context);
      }
    }
  }

  @override
  PaintEntry hitTest(Offset location) {
    if (offset == null) return null;

    location = location - offset;
    if (location.dy < 0 || location.dy >= size.height) {
      return null;
    }
    // There is no need to optimize this but we could perform a binary search.
    for (var entry in entries) {
      if (entry.x <= location.dx && entry.right > location.dx) {
        return entry;
      }
    }
    return null;
  }
}

class InspectorTreeNodeCanvas extends InspectorTreeNode {
  @override
  InspectorTreeNodeRenderBuilder createRenderBuilder() {
    return InspectorTreeNodeRenderCanvasBuilder(
      level: diagnostic.level,
      treeStyle: diagnostic.style,
    );
  }
}

class InspectorTreeCanvas extends InspectorTreeFixedRowHeight
    implements InspectorTreeWeb {
  InspectorTreeCanvas({
    @required bool summaryTree,
    @required FlutterTreeType treeType,
    @required NodeAddedCallback onNodeAdded,
    VoidCallback onSelectionChange,
    TreeEventCallback onExpand,
    TreeHoverEventCallback onHover,
  }) : super(
          summaryTree: summaryTree,
          treeType: treeType,
          onNodeAdded: onNodeAdded,
          onSelectionChange: onSelectionChange,
          onExpand: onExpand,
          onHover: onHover,
        ) {
    _viewportCanvas = ViewportCanvas(
      paintCallback: _paintCallback,
      onTap: onTap,
      onMouseMove: onMouseMove,
      onMouseLeave: onMouseLeave,
      onSizeChange: _updateForContainerResize,
      classes: 'inspector-tree inspector-tree-container',
    );
  }

  void _updateForContainerResize(Size size) {
    _viewportCanvas.setContentSize(_computeContentWidth(size),
        (rowHeight * numRows + verticalPadding * 2).toDouble());
  }

  void _paintCallback(CanvasRenderingContext2D canvas, Rect rect) {
    final int startRow = getRowIndex(rect.top);
    final int endRow = math.min(getRowIndex(rect.bottom) + 1, numRows);
    for (int i = startRow; i < endRow; i++) {
      paintRow(canvas, i, rect);
    }
  }

  bool _recomputeRows = false;

  @override
  void setState(modifyState) {
    // More closely match Flutter semantics where state is set immediately
    // instead of after a frame.
    modifyState();
    if (!_recomputeRows) {
      _recomputeRows = true;
      window.requestAnimationFrame((_) => _rebuildData());
    }
  }

  double _computeContentWidth(Size size) {
    double maxIndent = 0;
    for (int i = 0; i < numRows; i++) {
      final InspectorTreeRow row = root?.getRow(i, selection: selection);
      if (row != null) {
        maxIndent = max(maxIndent, getDepthIndent(row.depth));
      }
    }
    return maxIndent + size.width;
  }

  void _rebuildData() {
    if (_recomputeRows) {
      _recomputeRows = false;
      if (root != null) {
        _updateForContainerResize(_viewportCanvas.viewport.size);
      } else {
        _viewportCanvas.setContentSize(0, 0);
      }
    }
    _viewportCanvas.rebuild(force: true);
  }

  @override
  String get tooltip => _viewportCanvas.element.tooltip;

  @override
  set tooltip(String value) {
    _viewportCanvas.element.tooltip = value;
  }

  void onMouseLeave() {
    if (onHover != null) {
      onHover(null, null);
    }
  }

  ViewportCanvas _viewportCanvas;

  @override
  CoreElement get element => _viewportCanvas.element;

  @override
  InspectorTreeNode createNode() => InspectorTreeNodeCanvas();

  void paintRow(
    CanvasRenderingContext2D canvas,
    int index,
    Rect visible,
  ) {
    canvas.save();
    final double y = getRowY(index);
    canvas.translate(0, y);
    // Variables incremented as part of painting.
    double currentX = 0;
    Color currentColor;

    bool isVisible(double width) {
      return currentX <= visible.right && visible.left <= currentX + width;
    }

    final InspectorTreeRow row = root?.getRow(index, selection: selection);
    if (row == null) {
      return;
    }
    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    final InspectorTreeNodeCanvasRender renderObject = node.renderObject;

    bool hasPath = false;
    void _endPath() {
      if (!hasPath) return;
      canvas.stroke();
      hasPath = false;
    }

    void _maybeStart([Color color = Colors.grey]) {
      if (color != currentColor) {
        _endPath();
      }
      if (hasPath) return;
      hasPath = true;
      canvas.beginPath();
      if (currentColor != color) {
        currentColor = color;
        canvas.strokeStyle = colorToCss(color);
      }
      canvas.lineWidth = chartLineStrokeWidth;
    }

    for (int tick in row.ticks) {
      currentX = getDepthIndent(tick) - columnWidth * 0.5;
      if (isVisible(1.0)) {
        final highlight = row.highlightDepth == tick;
        _maybeStart(highlight ? highlightLineColor : defaultTreeLineColor);
        canvas
          ..moveTo(currentX, 0.0)
          ..lineTo(currentX, rowHeight);
      }
    }
    if (row.lineToParent) {
      final highlight = row.highlightDepth == row.depth - 1;
      currentX = getDepthIndent(row.depth - 1) - columnWidth * 0.5;
      final double width = showExpandCollapse ? columnWidth * 0.5 : columnWidth;
      if (isVisible(width)) {
        _maybeStart(highlight ? highlightLineColor : defaultTreeLineColor);
        canvas
          ..moveTo(currentX, 0.0)
          ..lineTo(currentX, rowHeight * 0.5)
          ..lineTo(currentX + width, rowHeight * 0.5);
      }
    }
    _endPath();

    // Render the main row content.

    currentX = getDepthIndent(row.depth) - columnWidth;
    if (!row.node.showExpandCollapse) {
      currentX += columnWidth;
    }
    if (renderObject == null) {
      // Short circuit as nothing can be drawn within the view.
      canvas.restore();
      return;
    }
    renderObject.attach(this, Offset(currentX, y));
    final Rect paintBounds = renderObject.paintBounds;
    if (!paintBounds.overlaps(visible)) {
      canvas.restore();
      return;
    }

    if (row.isSelected || row.node == hover) {
      final Color backgroundColor =
          row.isSelected ? selectedRowBackgroundColor : hoverColor;
      final double x = getDepthIndent(row.depth) - columnWidth * 0.15;
      if (x <= visible.right) {
        final fillStyle = canvas.fillStyle;
        canvas.fillStyle = colorToCss(backgroundColor);
        canvas.fillRect(
            x, 0.0, math.min(visible.right, paintBounds.right) - x, rowHeight);
        canvas.fillStyle = fillStyle;
      }
    }
    // We have already translated to the offset in the y axis.
    canvas.translate(currentX, 0);
    renderObject.paint(canvas, visible);
    canvas.restore();
  }

  @override
  Rect getBoundingBox(InspectorTreeRow row) {
    return Rect.fromLTWH(
      getDepthIndent(row.depth),
      getRowY(row.index),
      // Hack as we don't know exactly how wide the row is (yet).
      // TODO(jacobr): tweak measurement code so we do.
      _viewportCanvas.viewport.width * .7,
      rowHeight,
    );
  }

  @override
  void scrollToRect(Rect targetRect) {
    _viewportCanvas.scrollToRect(targetRect);
  }
}
