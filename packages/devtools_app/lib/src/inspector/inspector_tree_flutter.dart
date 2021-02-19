// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedantic/pedantic.dart';

import '../auto_dispose_mixin.dart';
import '../collapsible_mixin.dart';
import '../common_widgets.dart';
import '../error_badge_manager.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/utils.dart';
import 'diagnostics.dart';
import 'diagnostics_node.dart';
import 'inspector_tree.dart';

/// Presents a [TreeNode].
class _InspectorTreeRowWidget extends StatefulWidget {
  /// Constructs a [_InspectorTreeRowWidget] that presents a line in the
  /// Inspector tree.
  const _InspectorTreeRowWidget({
    @required Key key,
    @required this.row,
    @required this.inspectorTreeState,
    this.error,
    @required this.scrollControllerX,
    @required this.viewportWidth,
  }) : super(key: key);

  final _InspectorTreeState inspectorTreeState;

  InspectorTreeNode get node => row.node;
  final InspectorTreeRow row;
  final ScrollController scrollControllerX;
  final double viewportWidth;

  /// A [DevToolsError] that applies to the widget in this row.
  ///
  /// This will be null if there is no error for this row.
  final DevToolsError error;

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
        error: widget.error,
        expandArrowAnimation: expandArrowAnimation,
        controller: widget.inspectorTreeState.controller,
        scrollControllerX: widget.scrollControllerX,
        viewportWidth: widget.viewportWidth,
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

class InspectorTreeControllerFlutter extends Object
    with InspectorTreeController, InspectorTreeFixedRowHeightController {
  /// Client the controller notifies to trigger changes to the UI.
  final Set<InspectorControllerClient> _clients = {};

  void addClient(InspectorControllerClient value) {
    final firstClient = _clients.isEmpty;
    _clients.add(value);
    if (firstClient) {
      config.onClientActiveChange(true);
    }
  }

  void removeClient(InspectorControllerClient value) {
    _clients.remove(value);
    if (_clients.isEmpty) {
      config.onClientActiveChange(false);
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
    for (var client in _clients) {
      client.scrollToRect(targetRect);
    }
  }

  @override
  void setState(VoidCallback fn) {
    fn();
    for (var client in _clients) {
      client.onChanged();
    }
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

  void requestFocus() {
    for (var client in _clients) {
      client.requestFocus();
    }
  }
}

abstract class InspectorControllerClient {
  void onChanged();

  void scrollToRect(Rect rect);

  void requestFocus();
}

class InspectorTree extends StatefulWidget {
  const InspectorTree({
    Key key,
    @required this.controller,
    this.isSummaryTree = false,
    this.widgetErrors,
  }) : super(key: key);

  final InspectorTreeController controller;
  final bool isSummaryTree;
  final LinkedHashMap<String, InspectableWidgetError> widgetErrors;

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
  InspectorTreeControllerFlutter get controller => widget.controller;

  bool get isSummaryTree => widget.isSummaryTree;

  ScrollController _scrollControllerY;
  ScrollController _scrollControllerX;
  Future<void> currentAnimateY;
  Rect currentAnimateTarget;

  AnimationController constraintDisplayController;
  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    // TODO(devoncarew): Commented out as per flutter/devtools/pull/2001.
    //_scrollControllerY.addListener(_onScrollYChange);
    if (isSummaryTree) {
      constraintDisplayController = longAnimationController(this);
    }
    _focusNode = FocusNode();
    _bindToController();
  }

  @override
  void didUpdateWidget(InspectorTree oldWidget) {
    if (oldWidget.controller != widget.controller) {
      final InspectorTreeControllerFlutter oldController = oldWidget.controller;
      oldController?.removeClient(this);
      cancel();

      _bindToController();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    controller?.removeClient(this);
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    constraintDisplayController?.dispose();
    _focusNode.dispose();
  }

  @override
  void requestFocus() {
    _focusNode.requestFocus();
  }

  // TODO(devoncarew): Commented out as per flutter/devtools/pull/2001.
//  void _onScrollYChange() {
//    if (controller == null) return;
//
//    // If the vertical position  is already being animated we should not trigger
//    // a new animation of the horizontal position as a more direct animation of
//    // the horizontal position has already been triggered.
//    if (currentAnimateY != null) return;
//
//    final x = _computeTargetX(_scrollControllerY.offset);
//    _scrollControllerX.animateTo(
//      x,
//      duration: defaultDuration,
//      curve: defaultCurve,
//    );
//  }

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
    final endY = y += safeViewportHeight;
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
    final targetY = _computeTargetOffsetY(
      rect.top,
      rect.bottom,
    );
    if (_scrollControllerY.hasClients) {
      currentAnimateY = _scrollControllerY.animateTo(
        targetY,
        duration: longDuration,
        curve: defaultCurve,
      );
    } else {
      currentAnimateY = null;
      _scrollControllerY = ScrollController(initialScrollOffset: targetY);
    }

    // Determine a target X coordinate consistent with the target Y coordinate
    // we will end up as so we get a smooth animation to the final destination.
    final targetX = _computeTargetX(targetY);
    if (_scrollControllerX.hasClients) {
      unawaited(_scrollControllerX.animateTo(
        targetX,
        duration: longDuration,
        curve: defaultCurve,
      ));
    } else {
      _scrollControllerX = ScrollController(initialScrollOffset: targetX);
    }

    try {
      await currentAnimateY;
    } catch (e) {
      // Doesn't matter if the animation was cancelled.
    }
    currentAnimateY = null;
    currentAnimateTarget = null;
  }

  // TODO(jacobr): resolve cases where we need to know the viewport height
  // before it is available so we don't need this approximation.
  /// Placeholder viewport height to use if we don't yet know the real
  /// viewport height.
  static const _placeholderViewportHeight = 1000.0;

  double get safeViewportHeight {
    return _scrollControllerY.hasClients
        ? _scrollControllerY.position.viewportDimension
        : _placeholderViewportHeight;
  }

  /// Animate so that the entire range minOffset to maxOffset is within view.
  double _computeTargetOffsetY(
    double minOffset,
    double maxOffset,
  ) {
    final currentOffset = _scrollControllerY.hasClients
        ? _scrollControllerY.offset
        : _scrollControllerY.initialScrollOffset;
    final viewportDimension = safeViewportHeight;
    final currentEndOffset = viewportDimension + currentOffset;

    // If the requested range is larger than what the viewport can show at once,
    // prioritize showing the start of the range.
    maxOffset = min(viewportDimension + minOffset, maxOffset);
    if (currentOffset <= minOffset && currentEndOffset >= maxOffset) {
      return currentOffset; // Nothing to do. The whole range is already in view.
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

  /// Handle arrow keys for the InspectorTree. Ignore other key events so that
  /// other widgets have a chance to respond to them.
  bool _handleKeyEvent(FocusNode _, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller.navigateDown();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller.navigateUp();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      controller.navigateLeft();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      controller.navigateRight();
      return true;
    }

    return false;
  }

  void _bindToController() {
    controller?.addClient(this);
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
      return const CenteredCircularProgressIndicator();
    }
    if (controller.numRows == 0) {
      // This works around a bug when Scrollbars are present on a short lived
      // widget.
      return const SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        return Scrollbar(
          isAlwaysShown: true,
          controller: _scrollControllerX,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollControllerX,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: controller.rowWidth + controller.maxRowIndent),
              // TODO(kenz): this scrollbar needs to be sticky to the right side of
              // the visible container - right now it is lined up to the right of
              // the widest row (which is likely not visible). This may require some
              // refactoring.
              child: GestureDetector(
                onTap: _focusNode.requestFocus,
                child: Focus(
                  onKey: _handleKeyEvent,
                  autofocus: widget.isSummaryTree,
                  focusNode: _focusNode,
                  child: OffsetScrollbar(
                    isAlwaysShown: true,
                    axis: Axis.vertical,
                    controller: _scrollControllerY,
                    offsetController: _scrollControllerX,
                    offsetControllerViewportDimension: viewportWidth,
                    child: ListView.custom(
                      itemExtent: rowHeight,
                      childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final InspectorTreeRow row =
                              controller.root?.getRow(index);
                          final inspectorRef =
                              row.node.diagnostic?.valueRef?.id;
                          return _InspectorTreeRowWidget(
                            key: PageStorageKey(row?.node),
                            inspectorTreeState: this,
                            row: row,
                            scrollControllerX: _scrollControllerX,
                            viewportWidth: viewportWidth,
                            error: widget.widgetErrors != null &&
                                    inspectorRef != null
                                ? widget.widgetErrors[inspectorRef]
                                : null,
                          );
                        },
                        childCount: controller.numRows,
                      ),
                      controller: _scrollControllerY,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Paint _defaultPaint(ColorScheme colorScheme) => Paint()
  ..color = colorScheme.treeGuidelineColor
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
  _RowPainter(this.row, this._controller, this.colorScheme);

  final InspectorTreeController _controller;
  final InspectorTreeRow row;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    double currentX = 0;
    final paint = _defaultPaint(colorScheme);

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
        paint,
      );
    }
    // If this row is itself connected to a parent then draw the L shaped line
    // to make that connection.
    if (row.lineToParent) {
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
    if (oldDelegate is _RowPainter) {
      // TODO(jacobr): check whether the row has different ticks.
      return oldDelegate.colorScheme.isLight != colorScheme.isLight;
    }
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
    this.error,
    @required this.scrollControllerX,
    @required this.viewportWidth,
  });

  final InspectorTreeRow row;
  final InspectorTreeControllerFlutter controller;
  final VoidCallback onToggle;
  final Animation<double> expandArrowAnimation;
  final ScrollController scrollControllerX;
  final double viewportWidth;

  /// A [DevToolsError] that applies to the widget in this row.
  ///
  /// This will be null if there is no error for this row.
  final DevToolsError error;

  /// Whether this row has any error.
  bool get hasError => error != null;

  @override
  Widget build(BuildContext context) {
    final double currentX = controller.getDepthIndent(row.depth) - columnWidth;
    final colorScheme = Theme.of(context).colorScheme;

    if (row == null) {
      return const SizedBox();
    }
    Color backgroundColor;
    if (row.isSelected) {
      backgroundColor =
          hasError ? devtoolsError : colorScheme.selectedRowBackgroundColor;
    } else if (row.node == controller.hover) {
      backgroundColor = colorScheme.hoverColor;
    }

    final node = row.node;

    Widget rowWidget = Padding(
      padding: EdgeInsets.only(left: currentX),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          node.showExpandCollapse
              ? InkWell(
                  onTap: onToggle,
                  child: RotationTransition(
                    turns: expandArrowAnimation,
                    child: const Icon(
                      Icons.expand_more,
                      size: defaultIconSize,
                    ),
                  ),
                )
              : const SizedBox(width: defaultSpacing, height: defaultSpacing),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                border: hasError ? Border.all(color: devtoolsError) : null,
              ),
              child: InkWell(
                onTap: () {
                  controller.onSelectRow(row);
                  // TODO(gmoothart): It may be possible to capture the tap
                  // and request focus directly from the InspectorTree. Then
                  // we wouldn't need this.
                  controller.requestFocus();
                },
                child: Container(
                  height: rowHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: DiagnosticsNodeDescription(node.diagnostic),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Wrap with error tooltip/marker if there is an error for this node's widget.
    if (hasError) {
      rowWidget = Stack(
        children: [
          rowWidget,
          ErrorIndicator(
            error: error,
            indent: currentX,
          ),
        ],
      );
    }

    return CustomPaint(
      painter: _RowPainter(row, controller, colorScheme),
      size: Size(currentX, rowHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: scrollControllerX,
          builder: (context, child) {
            final rowWidth =
                scrollControllerX.offset + viewportWidth - defaultSpacing;
            return SizedBox(
              width: max(rowWidth, currentX + 100),
              child: rowWidth > currentX ? child : const SizedBox(),
            );
          },
          child: rowWidget,
        ),
      ),
    );
  }
}

class ErrorIndicator extends StatelessWidget {
  const ErrorIndicator({
    Key key,
    @required this.error,
    @required this.indent,
  }) : super(key: key);

  final DevToolsError error;
  final double indent;

  /// [indent] is where the row content starts, so the indicator should be
  /// offset some to the left to avoid overlapping with the guidelines and
  /// expand/collapse widgets (plus to account for its own width).
  static const double indicatorOffset = -(defaultIconSize * 2 + denseSpacing);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: error.errorMessage,
      child: Padding(
        padding: EdgeInsets.only(
          left: indent + indicatorOffset,
          top: (rowHeight - defaultIconSize) / 2,
        ),
        child: Container(
          width: defaultIconSize,
          height: defaultIconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error.read ? null : devtoolsError,
            border: error.read ? Border.all(color: devtoolsError) : null,
          ),
        ),
      ),
    );
  }
}
