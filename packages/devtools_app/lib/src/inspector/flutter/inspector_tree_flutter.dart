// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/collapsible_mixin.dart';
import '../../flutter/extent_delegate_list.dart';
import '../../flutter/theme.dart';
import '../../ui/colors.dart';
import '../../utils.dart';
import '../diagnostics_node.dart';
import '../inspector_tree.dart';
import 'diagnostics.dart';

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
    return SizedBox(
      height: rowHeight,
      child: InspectorRowContent(
        row: widget.row,
        expandArrowAnimation: expandArrowAnimation,
        controller: widget.inspectorTreeState.controller,
        onToggle: () {
          setExpanded(!isExpanded);
        },
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

/// Presents a [TreeNode].
class _AnimatedInspectorTreeRowWidget extends StatefulWidget {
  /// Constructs a [_InspectorTreeRowWidget] that presents a line in the
  /// Inspector tree.
  const _AnimatedInspectorTreeRowWidget({
    @required Key key,
    @required this.row,
    @required this.inspectorTreeState,
    @required this.visibilityCurve,
  }) : super(key: key);

  final _InspectorTreeState inspectorTreeState;
  final Animation<double> visibilityCurve;

  InspectorTreeNode get node => row.node;
  final AnimatedRow row;

  @override
  _AnimatedInspectorTreeRowState createState() =>
      _AnimatedInspectorTreeRowState();
}

class _AnimatedInspectorTreeRowState
    extends State<_AnimatedInspectorTreeRowWidget>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedInspectorRowContent(
      row: widget.row,
      expandArrowAnimation: expandArrowAnimation,
      controller: widget.inspectorTreeState.controller,
      visibilityAnimation: widget.visibilityCurve,
      onToggle: () {
        setExpanded(!isExpanded);
      },
    );
  }

  @override
  bool get isExpanded => widget.node.isExpanded;

  @override
  void onExpandChanged(bool expanded) {
    setState(() {
      final row = widget.row;
      if (row.current == null) {
        // Don't allow manipulating rows that are animating out.
        return;
      }
      if (expanded) {
        widget.inspectorTreeState.controller.onExpandRow(row.current);
      } else {
        widget.inspectorTreeState.controller.onCollapseRow(row.current);
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

class NodeYPair {
  const NodeYPair(this.node, this.y);

  final InspectorTreeNode node;
  final double y;
}

class InspectorTree extends StatefulWidget {
  const InspectorTree({
    Key key,
    @required this.controller,
    this.isSummaryTree = false,
  }) : super(key: key);

  final InspectorTreeController controller;
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
  BoxConstraints _lastConstraints;

  InspectorTreeControllerFlutter get controller => widget.controller;

  bool get isSummaryTree => widget.isSummaryTree;

  ScrollController _scrollControllerY;
  ScrollController _scrollControllerX;
  Future<void> currentAnimateY;
  Rect currentAnimateTarget;

  AnimationController visibilityController;

  /// A curved animation that matches [expandController], moving from 0.0 to 1.0
  /// Useful for animating the size of a child that is appearing.
  Animation<double> visibilityCurve;
  FixedExtentDelegate extentDelegate;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    _scrollControllerY.addListener(_onScrollYChange);
    visibilityController = longAnimationController(this);
    visibilityCurve = defaultCurvedAnimation(visibilityController);
    visibilityController.addStatusListener((status) {
      setState(() {});
      if (AnimationStatus.completed == status ||
          AnimationStatus.dismissed == status) {
        print("XX status done. TODO(jacobr): do somethign");
      }
    });
    extentDelegate = FixedExtentDelegate(
      computeExtent: (index) {
        if (controller?.animatedRows == null) return 0;
          if (index == 0) {
            return topAnimation?.value ?? 0;
          }
          if (index == controller.animatedRows.length + 1) {
            return bottomAnimation?.value ?? 0.0;
          }
          return controller.animatedRows[index - 1].animatedRowHeight(
              visibilityCurve);
        },
        computeLength: () {
        final rows = controller?.animatedRows;
          if (rows == null) return 0;
          return rows.length + 2;
        }
    );
    visibilityController.addListener(extentDelegate.recompute);
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
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    visibilityController?.dispose();
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
      duration: defaultDuration,
      curve: defaultCurve,
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

    // If there is no target offset, use zero.
    if (minOffset == double.infinity) return 0;

    return minOffset;
  }

  @override
  Future<void> scrollToRect(Rect rect) async {
    // TODO(jacobr): this probably needs to be reworked.
    if (rect == currentAnimateTarget) {
      // We are in the middle of an animation to this exact rectangle.
      return;
    }
    currentAnimateTarget = rect;
    final targetY = _computeTargetOffsetY(
      _scrollControllerY,
      rect.top,
      rect.bottom,
    );
    assert(targetY != double.infinity);

    currentAnimateY = _scrollControllerY.animateTo(
      targetY,
      duration: longDuration,
      curve: defaultCurve,
    );

    // Determine a target X coordinate consistent with the target Y coordinate
    // we will end up as so we get a smooth animation to the final destination.
    final targetX = _computeTargetX(targetY);

    assert(targetX != double.infinity);
    unawaited(_scrollControllerX.animateTo(
      targetX,
      duration: longDuration,
      curve: defaultCurve,
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
  double _computeTargetOffsetY(
    ScrollController controller,
    double minOffset,
    double maxOffset,
  ) {
    // Probably needs to be reworked.
    final currentOffset = controller.offset;
    final viewportDimension = _scrollControllerY.position.viewportDimension;
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

  void _bindToController() {
    controller?.client = this;
  }

  List<AnimatedRow> _currentAnimatedRows;
  Tween<double> topTween;
  Tween<double> bottomTween;
  Animation<double> topAnimation;
  Animation<double> bottomAnimation;

  int get countSpacerAnimations {
    int count = 0;
    if (topAnimation != null) count++;
    if (bottomAnimation != null) count++;
    return count;
  }

  @override
  void onChanged() {

    if (_currentAnimatedRows != controller.animatedRows) {
      final lastAnimatedRows = _currentAnimatedRows;

      double viewHeight = 1000.0; // Arbitrary. We could let it be zero.
      if (_lastConstraints != null) {
        viewHeight = _lastConstraints.maxHeight;
      }

      final lastTopSpacerHeight = topAnimation?.value ?? 0;
      double y = lastTopSpacerHeight;

      double scrollY = _scrollControllerY.offset;
      final Map<InspectorTreeNode, double> visibleNodeOffsets =
          LinkedHashMap.identity();

      final selection = controller.selection;
      // Determine where relevant nodes were in the previous animation.
      if (lastAnimatedRows != null) {
        for (final row in lastAnimatedRows) {
          final height = row.animatedRowHeight(visibilityCurve);
          // We are only interested in nodes that are still relevant for the
          // new animation which means only nodes from the end of the previous
          // animation.
          final node = row.current?.node;
          if (node != null) {
            if (y + height >= scrollY && y <= scrollY + viewHeight) {
              visibleNodeOffsets[node] = y;
            }
          }
          y += height;
        }
      }


      controller.optimizeRowAnimation(
          visibleNodeOffsets.keys.safeFirst, visibleNodeOffsets.keys.safeLast);
      _currentAnimatedRows = controller.animatedRows;

      InspectorTreeNode fixedPointNode;
      if (selection != null && visibleNodeOffsets.containsKey(selection)) {
        fixedPointNode = selection;
      } else {
        for (var row in _currentAnimatedRows) {
          final node = row.current?.node;
          if (node != null && visibleNodeOffsets.containsKey(node)) {
            fixedPointNode = node;
            break;
          }
        }
      }

      double beginY = 0;
      double endY = 0;

      double targetDelta;
      double nextFixedPointY;
      for (int i = 0; i < _currentAnimatedRows.length; ++i) {
        final row = _currentAnimatedRows[i];
        final lastNode = row.last?.node;
        final currentNode = row.current?.node;
        if (currentNode != null && currentNode == fixedPointNode) {
          // We are only interested in nodes that are still relevant for the
          // new animation which means only nodes from the end of the previous
          // animation
          targetDelta = endY - beginY;
          nextFixedPointY = beginY;
        }

        beginY += row.beginHeight;
        endY += row.endHeight;
      }

      double targetOffset = null;
      if (targetDelta != null) {
        if (targetDelta > 0) {
          topTween = Tween(begin: targetDelta, end: 0);
        } else {
          topTween = Tween(begin: 0, end: -targetDelta);
        }
        final fixedPointY = visibleNodeOffsets[fixedPointNode];
        if (fixedPointY != null && nextFixedPointY != null) {
          final fixedPointDelta =
              (nextFixedPointY + topTween.begin) - fixedPointY;
          targetOffset = _scrollControllerY.offset + fixedPointDelta;
          if (targetOffset < 0) {
            topTween = Tween(
                begin: topTween.begin - targetOffset,
                end: topTween.end - targetOffset);
            targetOffset = 0;
          }
        }
        topAnimation = topTween.animate(visibilityCurve);
      } else {
        topTween = null;
        topAnimation = null;
      }

      // XXX not right.
      double lengthDelta = endY - beginY;
      if (lengthDelta > 0) {
        bottomTween = Tween(begin: lengthDelta, end: 0);
      } else {
        bottomTween = Tween(begin: 0, end: -lengthDelta);
      }
      // TODO(jacobr): grow the bottom tween to make room for scrolls to the bottom of the list?
      bottomAnimation = bottomTween.animate(visibilityCurve);
      final yOffset = _scrollControllerY.offset;

      // We have a new animation to run. Cancel the old animation.
      visibilityController.reset();
      visibilityController.animateTo(1, duration: longDuration);

      // TODO(jacobr): more gracefully handle existing animations by
      // tracking what the current animation value was.
      if (targetOffset != null &&
          (targetOffset - _scrollControllerY.offset).abs() >= 0.001) {
        print("XXX JUMPED TO $targetOffset from ${_scrollControllerY.offset}");
        _scrollControllerY.jumpTo(targetOffset);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AnimatedList list;
    if (controller == null) {
      // Indicate the tree is loading.
      return const Center(child: CircularProgressIndicator());
    }
    final child = Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _scrollControllerX,
              child: SizedBox(
                width: controller.rowWidth + controller.maxRowIndent,
                child: ExtentDelegateListView(
                  extentDelegate: extentDelegate,
                  childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index == 0 || index == controller.animatedRowsLength + 1) {
                        return const SizedBox();
                      }
                      final row = controller.getAnimatedRow(index - 1);
                      if (row == null) return const SizedBox();
                      if (!row.animateRow) {
                        return _InspectorTreeRowWidget(
                          key: PageStorageKey(row?.node),
                          inspectorTreeState: this,
                          row: row.targetRow,
                        );
                      }
                      return _AnimatedInspectorTreeRowWidget(
                        key: PageStorageKey(row?.node),
                        inspectorTreeState: this,
                        row: row,
                        visibilityCurve: visibilityCurve,
                      );
                    },
                    childCount: controller.animatedRowsLength +
                        countSpacerAnimations,
                  ),
                  controller: _scrollControllerY,
                ),
              ),
            ),
          );
    return LayoutBuilder(builder: (context, constraints) {
      print("Constraints: $constraints");
      _lastConstraints = constraints;
      return child;
    });
    double f = double.nan;

  }

  @override
  bool get wantKeepAlive => true;
}

class AnimatedSpacer extends StatelessWidget {

  const AnimatedSpacer({
    Key key,
    @required this.animation, this.visibilityCurve,
  }) : super(key: key);

  final Animation<double> animation;
  final Animation<double> visibilityCurve;

  @override
  Widget build(BuildContext context) {
    print("XXX build AnimatedSpacer! ${animation?.value}");
    return AnimatedBuilder(
      animation: visibilityCurve,
      builder: (_, __) {
        if (animation == null) {
          return const SizedBox();
        }
        return SizedBox(height: animation.value);
      },
    );
  }
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
      if (row.ticks.isEmpty || row.ticks.last != row.depth - 1) {
        canvas.drawLine(
          Offset(currentX, 0.0),
          Offset(currentX, rowHeight * 0.5),
          paint,
        );
      }
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

/// Custom painter that draws lines indicating how parent and child rows are
/// connected to each other.
///
/// Each rows object contains a list of ticks that indicate the x coordinates of
/// vertical lines connecting other rows need to be drawn within the vertical
/// area of the current row. This approach has the advantage that a row contains
/// all information required to render all content within it but has the
/// disadvantage that the x coordinates of each line connecting rows must be
/// computed in advance.
class _AnimatedRowPainter extends CustomPainter {
  _AnimatedRowPainter(this.row, this._controller, this.visibilityAnimation);

  final InspectorTreeController _controller;
  final AnimatedRow row;
  final Animation<double> visibilityAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    double currentX = 0;

    if (this.row == null) {
      return;
    }
    final InspectorTreeNode node = this.row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    InspectorTreeRow row;
    // TODO(jacobr): really animate.
    if (visibilityAnimation.value < 1) {
      row = this.row.last;
    } else {
      row = this.row.current;
    }
    row ??= this.row.current;
    if (row == null) return;

    final rowHeight = this.row.animatedRowHeight(visibilityAnimation);
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
      if (row.ticks.isEmpty || row.ticks.last != row.depth - 1) {
        canvas.drawLine(
          Offset(currentX, 0.0),
          Offset(currentX, rowHeight * 0.5),
          paint,
        );
      }
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
    return true;
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
    @required this.expandArrowAnimation,
  });

  final InspectorTreeRow row;
  final InspectorTreeControllerFlutter controller;
  final VoidCallback onToggle;
  final Animation<double> expandArrowAnimation;

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
                        turns: expandArrowAnimation,
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
            ],
          ),
        ),
      ),
    );
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
class AnimatedInspectorRowContent extends StatelessWidget {
  const AnimatedInspectorRowContent({
    @required this.row,
    @required this.controller,
    @required this.onToggle,
    @required this.expandArrowAnimation,
    @required this.visibilityAnimation,
  });

  final AnimatedRow row;
  final InspectorTreeControllerFlutter controller;
  final VoidCallback onToggle;
  final Animation<double> expandArrowAnimation;
  final Animation<double> visibilityAnimation;

  @override
  Widget build(BuildContext context) {
    final double currentX =
        controller.getDepthIndent(row.depth(visibilityAnimation)) - columnWidth;

    if (row == null) {
      return const SizedBox();
    }
    Color backgroundColor;
    if (row.targetRow.isSelected || row.node == controller.hover) {
      backgroundColor =
          row.isSelected ? selectedRowBackgroundColor : hoverColor;
    }

    final node = row.node;
    return CustomPaint(
      painter: _AnimatedRowPainter(row, controller, visibilityAnimation),
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
                        turns: expandArrowAnimation,
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
                    controller.onSelectRow(row.targetRow);
                  },
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: DiagnosticsNodeDescription(node.diagnostic),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
