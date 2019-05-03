// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/rendering.dart' hide Icon;
import '../../ui/flutter/flutter_icon_renderer.dart';
import '../../ui/icons.dart';
import '../inspector_service.dart';
import '../inspector_tree.dart';
import '../inspector_tree_web.dart';

typedef CanvasPaintCallback = void Function(
  Canvas canvas,
  int index,
  Size size,
);

class InspectorTreeNodeRenderCanvasBuilder
    extends InspectorTreeNodeRenderBuilder<InspectorTreeNodeFlutterRender> {
  InspectorTreeNodeRenderCanvasBuilder({
    @required DiagnosticLevel level,
    @required DiagnosticsTreeStyle treeStyle,
  }) : super(level: level, treeStyle: treeStyle);

  final List<Widget> _entries = <Widget>[];

  @override
  void appendText(String text, TextStyle textStyle) {
    _entries.add(Text(text, style: textStyle));
  }

  @override
  void addIcon(DevToolsIcon icon) {
    // TODO(jacobr): add iconPadding to x;
    _entries.add(Padding(
      padding: const EdgeInsets.only(right: iconPadding),
      child: getIconWidget(icon),
    ));
  }

  @override
  InspectorTreeNodeFlutterRender build() {
    return InspectorTreeNodeFlutterRender(_entries);
  }
}

class InspectorTreeNodeFlutterRender extends InspectorTreeNodeRender<Widget> {
  InspectorTreeNodeFlutterRender(List<Widget> entries) : super(entries);

  @override
  PaintEntry hitTest(Offset location) {
    return null;
  }
}

class InspectorTreeNodeFlutter extends InspectorTreeNode {
  @override
  InspectorTreeNodeRenderBuilder createRenderBuilder() {
    return InspectorTreeNodeRenderCanvasBuilder(
      level: diagnostic.level,
      treeStyle: diagnostic.style,
    );
  }
}

class InspectorTreeFlutter extends StatefulWidget {
  const InspectorTreeFlutter({Key key}) : super(key: key);

  @override
  State<InspectorTreeFlutter> createState() {
    return InspectorTreeStateFlutter();
  }
}

final _highlightPaint = Paint()
  ..color = highlightLineColor
  ..strokeWidth = chartLineStrokeWidth;
final _defaultPaint = Paint()
  ..color = defaultTreeLineColor
  ..strokeWidth = chartLineStrokeWidth;

class _RowPainter extends CustomPainter {
  _RowPainter(this.row, this._tree);

  final InspectorTreeState _tree;
  final InspectorTreeRow row;

// XXX don't pass in the whole tree when we just need the depth indent
// final InspectorTreeState tree;

  @override
  void paint(Canvas canvas, Size size) {
    double currentX = 0;
    Color currentColor;

    if (row == null) {
      return;
    }
    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    for (int tick in row.ticks) {
      currentX = _tree.getDepthIndent(tick) - columnWidth * 0.5;
      //if (isVisible(1.0))
      {
        canvas.drawLine(
          Offset(currentX, 0.0),
          Offset(currentX, rowHeight),
          _defaultPaint,
        );
      }
    }
    if (row.lineToParent) {
      final paint = _defaultPaint;
      currentX = _tree.getDepthIndent(row.depth - 1) - columnWidth * 0.5;
      final double width = showExpandCollapse ? columnWidth * 0.5 : columnWidth;
      //if (isVisible(width))
      {
        canvas.drawLine(
          Offset(currentX, 0.0),
          Offset(currentX, rowHeight * 0.5),
          paint,
        );
        canvas.drawLine(
          Offset(currentX, rowHeight * 0.5),
          Offset(currentX + width, rowHeight * 0.5),
          paint,
        );
      }
    }

    // Render the main row content.

    currentX = _tree.getDepthIndent(row.depth) - columnWidth;
    if (!row.node.showExpandCollapse) {
      currentX += columnWidth;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class InspectorTreeStateFlutter extends State<InspectorTreeFlutter>
    with InspectorTreeState, InspectorTreeFixedRowHeightState {
  /*XXX void _paintCallback(Canvas canvas, Rect rect) {
    final int startRow = getRowIndex(rect.top);
    final int endRow = math.min(getRowIndex(rect.bottom) + 1, numRows);
    for (int i = startRow; i < endRow; i++) {
      paintRow(canvas, i, rect);
    }
  }*/
  final ScrollController _scrollController = ScrollController();
  @override
  String get tooltip => _tooltip;
  String _tooltip;
  @override
  set tooltip(String value) {
    // XXX setState or something?? This seems inefficent
    setState(() {
      _tooltip = tooltip;
    });
  }

  void onMouseLeave() {
    if (onHover != null) {
      onHover(null, null);
    }
  }

  @override
  InspectorTreeNode createNode() => InspectorTreeNodeFlutter();

  @override
  Rect getBoundingBox(InspectorTreeRow row) {
    return Rect.fromLTWH(
      getDepthIndent(row.depth),
      getRowY(row.index),
      // Hack as we don't know exactly how wide the row is (yet).
      // TODO(jacobr): tweak measurement code so we do.
      600, // ???
      rowHeight,
    );
  }

  @override
  void scrollToRect(Rect targetRect) {
    throw 'Not supported yet';
    // _viewportCanvas.scrollToRect(targetRect);
  }

  Widget _buildRow(BuildContext context, int index) {
    final InspectorTreeRow row = root?.getRow(index);
    final double currentX = getDepthIndent(row.depth) - columnWidth;

    if (row == null) {
      return const Text(
          'No Row'); // XXX what is the correct placeholder? Maybe null.
    }
    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    final InspectorTreeNodeFlutterRender parts = node.renderObject;
    Color backgroundColor;
    if (row.isSelected || row.node == hover) {
      backgroundColor =
          row.isSelected ? selectedRowBackgroundColor : hoverColor;
      // XXX final double x = getDepthIndent(row.depth) - columnWidth * 0.15;
      // if (x <= visible.right)
    }

    return CustomPaint(
      painter: _RowPainter(row, this),
      size: Size(currentX + 1000, rowHeight),
      child: Container(
        margin: EdgeInsets.only(left: currentX),
        color: backgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: parts.entries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.custom(
      itemExtent: rowHeight,
      childrenDelegate: SliverChildBuilderDelegate(
        _buildRow,
        childCount: numRows,
        addAutomaticKeepAlives: false,
        //addRepaintBoundaries: false, ??
//        this.addRepaintBoundaries = true,
//        addSemanticIndexes: false,
      ),
      controller: _scrollController,
    );
  }
}
