// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Icon;
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';

import '../../ui/flutter/flutter_icon_renderer.dart';
import '../../ui/icons.dart';
import '../inspector_tree.dart';

typedef CanvasPaintCallback = void Function(
  Canvas canvas,
  int index,
  Size size,
);

class InspectorTreeNodeWidgetBuilder
    extends InspectorTreeNodeRenderBuilder<InspectorTreeNodeFlutterRender> {
  InspectorTreeNodeWidgetBuilder({
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
    _entries.add(
      Padding(
        padding: const EdgeInsets.only(right: iconPadding),
        child: getIconWidget(icon),
      ),
    );
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
    return InspectorTreeNodeWidgetBuilder(
      level: diagnostic.level,
      treeStyle: diagnostic.style,
    );
  }
}

class InspectorTree extends StatefulWidget {
  const InspectorTree({Key key, this.controller}) : super(key: key);

  final InspectorTreeControllerFlutter controller;

  @override
  State<InspectorTree> createState() => InspectorTreeState();
}

final _defaultPaint = Paint()
  ..color = defaultTreeLineColor
  ..strokeWidth = chartLineStrokeWidth;

class _RowPainter extends CustomPainter {
  _RowPainter(this.row, this._controller);

  final InspectorTreeController _controller;
  final InspectorTreeRow row;

// XXX don't pass in the whole tree when we just need the depth indent
// final InspectorTreeState tree;

  @override
  void paint(Canvas canvas, Size size) {
    double currentX = 0;

    if (row == null) {
      return;
    }
    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    for (int tick in row.ticks) {
      currentX = _controller.getDepthIndent(tick) - columnWidth * 0.5;
      canvas.drawLine(
        Offset(currentX, 0.0),
        Offset(currentX, rowHeight),
        _defaultPaint,
      );
    }
    if (row.lineToParent) {
      final paint = _defaultPaint;
      currentX = _controller.getDepthIndent(row.depth - 1) - columnWidth * 0.5;
      final double width = showExpandCollapse ? columnWidth * 0.5 : columnWidth;
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

    // Render the main row content.

    currentX = _controller.getDepthIndent(row.depth) - columnWidth;
    if (!row.node.showExpandCollapse) {
      currentX += columnWidth;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class InspectorTreeControllerFlutter extends Object
    with InspectorTreeController, InspectorTreeFixedRowHeightController {
  // TODO(jacobr): tweak tooltip code to make sense for Flutter.
  @override
  String get tooltip => _tooltip;
  String _tooltip;

  /// Client the controller notifies to trigger changes to the UI.
  InspectorControllerClient client;

  @override
  set tooltip(String value) {
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
      rowWidth,
      rowHeight,
    );
  }

  @override
  void scrollToRect(Rect targetRect) {
    client?.scrollToRect(targetRect);
  }

  @override
  void setState(VoidCallback fn) {
    fn();
    client?.onChanged();
  }

  /// Width each row in the tree should have ignoring its indent.
  ///
  /// Content in rows should wrap if it exceeds this width.
  double rowWidth = 0;

  /// Maximum indent of the tree in pixels.
  double _maxIndent;

  double get maxRowIndent {
    if (lastContentWidth == null) {
      double maxIndent = 0;
      for (int i = 0; i < numRows; i++) {
        final row = getCachedRow(i);
        if (row != null) {
          maxIndent = max(maxIndent, getDepthIndent(row.depth));
        }
      }
      lastContentWidth = maxIndent + maxIndent;
      _maxIndent = maxIndent;
    }
    return _maxIndent;
  }
}

abstract class InspectorControllerClient {
  void onChanged();

  void scrollToRect(Rect rect);
}

class InspectorTreeState extends State<InspectorTree>
    implements InspectorControllerClient {
  final defaultAnimationDuration = const Duration(milliseconds: 150);
  final slowAnimationDuration = const Duration(milliseconds: 300);

  InspectorTreeControllerFlutter get controller => widget.controller;

  ScrollController _scrollControllerY;
  ScrollController _scrollControllerX;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    _scrollControllerY.addListener(_onScrollYChange);
    _bindToController();
  }

  void _onScrollYChange() {
    if (controller == null) return;

    // If the vertical position  is already being animated we should not trigger
    // a new animation of the horizontal position as a more direct animation of
    // the horizontal position has already been triggered.
    if (currentAnimateY != null) return;

    final x = _computeTargetX(_scrollControllerY.offset);
    _scrollControllerX.animateTo(
      x,
      duration: defaultAnimationDuration,
      curve: Curves.easeInOut,
    );
  }

  double _computeTargetX(double y) {
    final rowIndex = controller.getRowIndex(y);
    double requiredOffset;
    double minOffset = double.infinity;
    // TODO(jacobr): use maxOffset as well to deal better with jagged tables.
    if (rowIndex == controller.numRows) {
      return 0;
    }
    final endY = y += _scrollControllerY.position.viewportDimension;
    for (int i = rowIndex; i < controller.numRows; i++) {
      final rowY = controller.getRowY(i);
      if (rowY >= endY) break;

      final row = controller.getCachedRow(i);
      if (row == null) continue;
      final rowOffset = controller.getRowOffset(i);
      if (row.isSelected) {
        requiredOffset = rowOffset;
      }
      minOffset = min(minOffset, rowOffset);
    }
    if (requiredOffset == null) {
      return minOffset;
    }

    return minOffset;
  }

  Future<void> currentAnimateY;
  Rect currentAnimateTarget;

  @override
  Future<void> scrollToRect(Rect rect) async {
    if (rect == currentAnimateTarget) {
      // We are in the middle of an animation to this exact rectangle.
      return;
    }
    currentAnimateTarget = rect;
    final targetY = _computeTargetOffset(
      _scrollControllerY,
      rect.top,
      rect.bottom,
    );
    currentAnimateY = _scrollControllerY.animateTo(
      targetY,
      duration: slowAnimationDuration,
      curve: Curves.easeInOut,
    );

    // Determine a target X coordinate consistent with the target Y coordinate
    // we will end up as so we get a smooth animation to the final destination.
    final targetX = _computeTargetX(targetY);

    unawaited(_scrollControllerX.animateTo(
      targetX,
      duration: slowAnimationDuration,
      curve: Curves.easeInOut,
    ));

    try {
      await currentAnimateY;
    } catch (e) {
      // Doesn't matter if the animation was cancelled.
    }
    currentAnimateY = null;
    currentAnimateTarget = null;
  }

  /// Animate so that the entire range minOffset to maxOffset is within view.
  double _computeTargetOffset(
    ScrollController controller,
    double minOffset,
    double maxOffset,
  ) {
    final currentOffset = controller.offset;
    final viewportDimension = _scrollControllerX.position.viewportDimension;
    final currentEndOffset = viewportDimension + currentOffset;

    // If the requested range is larger than what the viewport can show at once,
    // prioritize showing the start of the range.
    maxOffset = min(viewportDimension + minOffset, maxOffset);
    if (currentOffset <= minOffset && currentEndOffset >= maxOffset) {
      return controller
          .offset; // Nothing to do. The whole range is already in view.
    }
    if (currentOffset > minOffset) {
      // Need to scroll so the minOffset is in view.
      return minOffset;
    }

    assert(currentEndOffset < maxOffset);
    // Need to scroll so the maxOffset is in view at the very bottom of the
    // list view.
    return maxOffset - viewportDimension;
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindToController();
  }

  void _bindToController() {
    controller?.client = this;
  }

  @override
  void dispose() {
    super.dispose();
    if (controller.client == this) {
      controller.client = null;
    }
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
  }

  @override
  void onChanged() {
    setState(() => {});
  }

  Widget _buildRow(BuildContext context, int index) {
    final InspectorTreeRow row = controller.root?.getRow(index);
    final double currentX = controller.getDepthIndent(row.depth) - columnWidth;

    if (row == null) {
      return const Text(
          'No Row'); // XXX what is the correct placeholder? Maybe null.
    }
    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    final InspectorTreeNodeFlutterRender parts = node.renderObject;
    Color backgroundColor;
    if (row.isSelected || row.node == controller.hover) {
      backgroundColor =
          row.isSelected ? selectedRowBackgroundColor : hoverColor;
      // XXX final double x = getDepthIndent(row.depth) - columnWidth * 0.15;
      // if (x <= visible.right)
    }

    return CustomPaint(
      painter: _RowPainter(row, controller),
      size: Size(
          currentX + controller.rowWidth + controller.maxRowIndent, rowHeight),
      child: Container(
        margin: EdgeInsets.only(left: currentX),
        color: backgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: parts?.entries ?? const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const LinearProgressIndicator();
    }
    // TODO(jacobr): this isn't a great place to be updating this.
    controller.rowWidth = min(MediaQuery.of(context).size.width * 0.7, 1024);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollControllerX,
      child: SizedBox(
        width: controller.rowWidth + controller.maxRowIndent,
        child: ListView.custom(
          itemExtent: rowHeight,
          childrenDelegate: SliverChildBuilderDelegate(
            _buildRow,
            childCount: controller.numRows,
            addAutomaticKeepAlives: false,
          ),
          controller: _scrollControllerY,
        ),
      ),
    );
  }
}
