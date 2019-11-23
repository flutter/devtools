// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/collapsible_mixin.dart';
import '../../ui/colors.dart';
import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import '../inspector_tree.dart';
import 'diagnostics.dart';
import 'inspector_data_models.dart';
import 'summary_tree_debug_layout.dart';

/// Presents a [TreeNode].
class _InspectorTreeRowWidget extends StatefulWidget {
  /// Constructs a [_InspectorTreeRowWidget] that presents a line in the
  /// Inspector tree.
  const _InspectorTreeRowWidget({
    @required Key key,
    @required this.row,
    @required this.inspectorTreeState,
  }) : super(key: key);

  final _InspectorTreeState inspectorTreeState;

  InspectorTreeNode get node => row.node;
  final InspectorTreeRow row;

  @override
  _InspectorTreeRowState createState() => _InspectorTreeRowState();
}

class _InspectorTreeRowState extends State<_InspectorTreeRowWidget>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: showController,
      builder: (context, child) {
        // TODO(jacobr): we aren't actually triggering this animation because
        // rows are currently only added to the tree when they are visible.
        // It isn't 100% clear this is the right animation due to show for large
        // tree expands due to https://github.com/flutter/devtools/issues/1227.
        // A better animation for the inspector case would likely be one that
        // "slides" the subtree into view instead of growing each subtree node
        // on its own as that would be more efficient.
        return SizedBox(
          height: rowHeight * showAnimation.value,
          child: Material(child: child),
        );
      },
      child: InspectorRowContent(
        row: widget.row,
        expandAnimation: expandAnimation,
        controller: widget.inspectorTreeState.controller,
        onToggle: () {
          setExpanded(!isExpanded);
        },
        constraintDisplayController:
            widget.inspectorTreeState.constraintDisplayController,
      ),
    );
  }

  @override
  bool get isExpanded => widget.node.isExpanded;

  @override
  void onExpandChanged(bool expanded) {
    setState(() {
      final row = widget.row;
      if (expanded) {
        widget.inspectorTreeState.controller.onExpandRow(row);
      } else {
        widget.inspectorTreeState.controller.onCollapseRow(row);
      }
    });
  }

  @override
  bool shouldShow() => widget.node.shouldShow;
}

class InspectorTreeControllerFlutter extends Object
    with InspectorTreeController, InspectorTreeFixedRowHeightController {
  /// Client the controller notifies to trigger changes to the UI.
  InspectorControllerClient get client => _client;
  InspectorControllerClient _client;

  set client(InspectorControllerClient value) {
    if (_client == value) return;
    // Do not set a new client if there is still an old client.
    assert(value == null || _client == null);
    _client = value;

    if (config.onClientActiveChange != null) {
      config.onClientActiveChange(value != null);
    }
  }

  @override
  InspectorTreeNode createNode() => InspectorTreeNode();

  @override
  Rect getBoundingBox(InspectorTreeRow row) {
    // For future reference: the bounding box likely needs to be in terms of
    // positions after the current animations are complete so that computations
    // to start animations to show specific widget scroll to where the target
    // nodes will be displayed rather than where they are currently displayed.
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
  final double rowWidth = 1200;

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

class InspectorTree extends StatefulWidget {
  const InspectorTree({
    Key key,
    @required this.controller,
    this.debugSummaryLayoutEnabled,
    this.isSummaryTree = false,
  }) : super(key: key);

  final InspectorTreeController controller;
  final ValueNotifier<bool> debugSummaryLayoutEnabled;
  final bool isSummaryTree;

  @override
  State<InspectorTree> createState() => _InspectorTreeState();
}

// AutomaticKeepAlive is necessary so that the tree does not get recreated when we switch tabs.
class _InspectorTreeState extends State<InspectorTree>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<InspectorTree>,
        AutoDisposeMixin
    implements InspectorControllerClient {
  final defaultAnimationDuration = const Duration(milliseconds: 150);
  final slowAnimationDuration = const Duration(milliseconds: 300);

  InspectorTreeControllerFlutter get controller => widget.controller;

  bool get isSummaryTree => widget.isSummaryTree;

  ValueNotifier get debugSummaryLayoutEnabled =>
      widget.debugSummaryLayoutEnabled;

  ScrollController _scrollControllerY;
  ScrollController _scrollControllerX;
  Future<void> currentAnimateY;
  Rect currentAnimateTarget;

  AnimationController constraintDisplayController;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    _scrollControllerY.addListener(_onScrollYChange);
    if (isSummaryTree) {
      constraintDisplayController = AnimationController(
        vsync: this,
        duration: slowAnimationDuration,
      );
    }
    _bindToController();
  }

  @override
  void didUpdateWidget(InspectorTree oldWidget) {
    if (oldWidget.controller != widget.controller) {
      final InspectorTreeControllerFlutter oldController = oldWidget.controller;
      oldController?.client = null;
      cancel();

      _bindToController();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    controller?.client = null;
    debugSummaryLayoutEnabled?.removeListener(
      _listenToDebugSummaryLayoutChanges,
    );
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    constraintDisplayController?.dispose();
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

  /// Compute the goal x scroll given a y scroll value.
  ///
  /// This enables animating the x scroll as the y scroll changes which helps
  /// keep the relevant content in view while scrolling a large list.
  double _computeTargetX(double y) {
    final rowIndex = controller.getRowIndex(y);
    double requiredOffset;
    double minOffset = double.infinity;
    // TODO(jacobr): use maxOffset as well to better handle the case where the
    // previous row has a significantly larger indent.

    // TODO(jacobr): if the first or last row is only partially visible, tween
    // between its indent and the next row to more smoothly change the target x
    // as the y coordinate changes.
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

  void _listenToDebugSummaryLayoutChanges() {
    if (debugSummaryLayoutEnabled.value) {
      constraintDisplayController.forward();
    } else {
      constraintDisplayController.reverse();
    }
  }

  void _bindToController() {
    controller?.client = this;
    if (isSummaryTree) {
      addAutoDisposeListener(
        debugSummaryLayoutEnabled,
        _listenToDebugSummaryLayoutChanges,
      );
    }
  }

  @override
  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (controller == null) {
      // Indicate the tree is loading.
      return const Center(child: CircularProgressIndicator());
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _scrollControllerX,
        child: SizedBox(
          width: controller.rowWidth + controller.maxRowIndent,
          child: Scrollbar(
            child: ListView.custom(
              itemExtent: rowHeight,
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) {
                  final InspectorTreeRow row = controller.root?.getRow(index);
                  return _InspectorTreeRowWidget(
                    key: PageStorageKey(row?.node),
                    inspectorTreeState: this,
                    row: row,
                  );
                },
                childCount: controller.numRows,
              ),
              controller: _scrollControllerY,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

final _defaultPaint = Paint()
// TODO(kenz): try to use color from Theme.of(context) for treeGuidelineColor
  ..color = treeGuidelineColor
  ..strokeWidth = chartLineStrokeWidth;

/// Custom painter that draws lines indicating how parent and child rows are
/// connected to each other.
///
/// Each rows object contains a list of ticks that indicate the x coordinates of
/// vertical lines connecting other rows need to be drawn within the vertical
/// area of the current row. This approach has the advantage that a row contains
/// all information required to render all content within it but has the
/// disadvantage that the x coordinates of each line connecting rows must be
/// computed in advance.
class _RowPainter extends CustomPainter {
  _RowPainter(this.row, this._controller);

  final InspectorTreeController _controller;
  final InspectorTreeRow row;

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
      // Draw a vertical line for each tick identifying a connection between
      // an ancestor of this node and some other node in the tree.
      canvas.drawLine(
        Offset(currentX, 0.0),
        Offset(currentX, rowHeight),
        _defaultPaint,
      );
    }
    // If this row is itself connected to a parent then draw the L shaped line
    // to make that connection.
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
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // TODO(jacobr): check whether the row has different ticks.
    return false;
  }
}

/// Widget defining the contents of a single row in the InspectorTree.
///
/// This class defines the scaffolding around the rendering of the actual
/// content of a [RemoteDiagnosticsNode] provided by
/// [DiagnosticsNodeDescription] to provide a tree implementation with lines
/// drawn between parent and child nodes when nodes have multiple children.
///
/// Changes to how the actual content of the node within the row should
/// be implemented by changing [DiagnosticsNodeDescription] instead.
class InspectorRowContent extends StatelessWidget {
  const InspectorRowContent({
    @required this.row,
    @required this.controller,
    @required this.onToggle,
    @required this.expandAnimation,
    @required this.constraintDisplayController,
  });

  final InspectorTreeRow row;
  final InspectorTreeControllerFlutter controller;
  final VoidCallback onToggle;
  final Animation<double> expandAnimation;
  final AnimationController constraintDisplayController;

  @override
  Widget build(BuildContext context) {
    final double currentX = controller.getDepthIndent(row.depth) - columnWidth;

    if (row == null) {
      return const SizedBox();
    }
    Color backgroundColor;
    if (row.isSelected || row.node == controller.hover) {
      backgroundColor =
          row.isSelected ? selectedRowBackgroundColor : hoverColor;
    }

    final node = row.node;
    return CustomPaint(
      painter: _RowPainter(row, controller),
      size: Size(currentX, rowHeight),
      child: Padding(
        padding: EdgeInsets.only(left: currentX),
        child: ClipRect(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            children: [
              node.showExpandCollapse
                  ? InkWell(
                      onTap: onToggle,
                      child: RotationTransition(
                        turns: expandAnimation,
                        child: const Icon(
                          Icons.expand_more,
                          size: 16.0,
                        ),
                      ),
                    )
                  : const SizedBox(width: 16.0, height: 16.0),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                ),
                child: InkWell(
                  onTap: () {
                    controller.onSelectRow(row);
                  },
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: DiagnosticsNodeDescription(node.diagnostic),
                  ),
                ),
              ),
              if (InspectorController.enableExperimentalStoryOfLayout &&
                  // fadeConstraintsAnimation is null for details tree rows
                  constraintDisplayController != null)
                ConstraintsDescription(
                  listenable: constraintDisplayController,
                  properties: LayoutProperties(node.diagnostic),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
