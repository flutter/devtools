// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import 'inspector_data_models.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController({
    this.detailsTree,
    this.actionButtons,
    this.controller,
    Key key,
  }) : super(key: key);

  final Widget detailsTree;
  final Widget actionButtons;
  final InspectorController controller;

  Widget _buildTab(String tabName) {
    return Tab(
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enableExperimentalStoryOfLayout =
        InspectorController.enableExperimentalStoryOfLayout;
    final tabs = <Tab>[
      _buildTab('Details Tree'),
      if (enableExperimentalStoryOfLayout) _buildTab('Layout Details'),
    ];
    final tabViews = <Widget>[
      detailsTree,
      if (enableExperimentalStoryOfLayout)
        LayoutDetailsTab(controller: controller),
    ];
    final focusColor = Theme.of(context).focusColor;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: focusColor),
      ),
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Container(
                      color: Theme.of(context).focusColor,
                      child: TabBar(
                        tabs: tabs,
                        isScrollable: true,
                      ),
                    ),
                  ),
                  if (actionButtons != null)
                    Expanded(
                      child: actionButtons,
                    ),
                ],
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LayoutDetailsTab extends StatefulWidget {
  const LayoutDetailsTab({Key key, this.controller}) : super(key: key);

  final InspectorController controller;

  @override
  _LayoutDetailsTabState createState() => _LayoutDetailsTabState();
}

class _LayoutDetailsTabState extends State<LayoutDetailsTab>
    with AutomaticKeepAliveClientMixin<LayoutDetailsTab> {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode get selected => controller?.selectedNode?.diagnostic;

  void onSelectionChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    controller.addSelectionListener(onSelectionChanged);
  }

  @override
  void dispose() {
    controller.removeSelectionListener(onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (selected == null) return const SizedBox();
    if (!selected.isFlex)
      // TODO(albertusangga): Visualize non-flex widget constraint model
      return Container(
        child: const Text(
          'TODOs for Non Flex widget',
        ),
      );
    return StoryOfYourFlexWidget(
      diagnostic: selected,
      // TODO(albertusangga): Cache this instead of recomputing every build
      properties: RenderFlexProperties.fromJson(selected.renderObject),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

@immutable
class StoryOfYourFlexWidget extends StatelessWidget {
  const StoryOfYourFlexWidget({
    this.diagnostic,
    this.properties,
    Key key,
  }) : super(key: key);

  final RemoteDiagnosticsNode diagnostic;
  final RenderFlexProperties properties;

  List<Widget> _visualizeChildren(BuildContext context) {
    if (!diagnostic.hasChildren) return [const SizedBox()];
    final theme = Theme.of(context);
    return [
      for (var child in diagnostic.childrenNow)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.focusColor,
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(child.description),
            ),
          ),
        ),
    ];
  }

  Widget _visualizeMainAxisAndCrossAxis(Widget child, double length) {
    return Center(
      child: GridAddOns(
        child: child,
        top: Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: BidirectionalHorizontalArrowWrapper(
            child: Text(
              properties.horizontalDirectionDescription,
            ),
          ),
          width: length,
        ),
        left: Container(
          height: length,
          margin: const EdgeInsets.only(right: 16.0, left: 8.0),
          child: BidirectionalVerticalArrowWrapper(
            child: Text(
              properties.verticalDirectionDescription,
            ),
            height: length,
          ),
        ),
        right: Container(
          height: length,
          margin: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: BidirectionalVerticalArrowWrapper(
            child: Text(
              properties.verticalDirectionDescription,
            ),
            height: length,
          ),
        ),
        bottom: Container(
          margin: const EdgeInsets.only(top: 16.0),
          child: BidirectionalHorizontalArrowWrapper(
            child: Text(
              properties.horizontalDirectionDescription,
            ),
          ),
          width: length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flexType = properties.type.toString();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 36.0),
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final children = _visualizeChildren(context);
              final flexDirectionWrapper = Flex(
                direction: properties.direction,
                children: children,
              );
              final childrenVisualizerWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      properties.type.toString(),
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                    ),
                    padding: const EdgeInsets.all(4.0),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                        top: 8.0,
                      ),
                      child: flexDirectionWrapper,
                    ),
                  ),
                ],
              );

              final minDimension = min(
                constraints.maxHeight * 0.75,
                constraints.maxWidth * 0.75,
              );
              final length = min(minDimension, 800.0);

              final flexVisualizerWidget = Container(
                width: length,
                height: length,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.accentColor,
                  ),
                  color: theme.primaryColor,
                ),
                child: childrenVisualizerWidget,
              );

              return _visualizeMainAxisAndCrossAxis(
                flexVisualizerWidget,
                length,
              );
            }),
          ),
        ],
      ),
    );
  }
}

@immutable
class BidirectionalVerticalArrowWrapper extends StatelessWidget {
  const BidirectionalVerticalArrowWrapper({
    Key key,
    @required this.child,
    this.height,
    this.arrowColor = Colors.white,
    this.arrowHeadSize = 16.0,
    this.arrowStrokeWidth = 2.0,
  })  : assert(child != null),
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final widget = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.up,
          ),
        ),
        Container(
          child: child,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.down,
          ),
        ),
      ],
    );
    if (height == null) return widget;
    return Container(height: height, child: widget);
  }
}

@immutable
class BidirectionalHorizontalArrowWrapper extends StatelessWidget {
  const BidirectionalHorizontalArrowWrapper({
    Key key,
    this.arrowColor = Colors.white,
    this.arrowHeadSize = 16.0,
    this.arrowStrokeWidth = 2.0,
    @required this.child,
  })  : assert(child != null),
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.left,
          ),
        ),
        Container(
          child: child,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.right,
          ),
        ),
      ],
    );
  }
}

///      | top    |
/// left | child  | right
///      | bottom |
@immutable
class GridAddOns extends StatelessWidget {
  const GridAddOns({
    Key key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    @required this.child,
  })  : assert(child != null),
        super(key: key);

  final Widget child;
  final Widget top;
  final Widget left;
  final Widget right;
  final Widget bottom;

  CrossAxisAlignment get crossAxisAlignment {
    if (left != null && right != null) {
      return CrossAxisAlignment.center;
    } else if (left == null && right != null) {
      return CrossAxisAlignment.start;
    } else if (left != null && right == null) {
      return CrossAxisAlignment.end;
    } else {
      return CrossAxisAlignment.start;
    }
  }

  @override
  Widget build(BuildContext context) {
    print(crossAxisAlignment);
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          if (top != null) top,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (left != null) left,
              Flexible(child: child),
              if (right != null) right,
            ],
          ),
          if (bottom != null) bottom,
        ]);
  }
}

enum ArrowType { up, left, right, down }

/// Widget that draws a fully sized, centered, unidirectional arrow according to its constraints
@immutable
class ArrowWidget extends StatelessWidget {
  const ArrowWidget({
    this.color = Colors.white,
    this.headSize = 16.0,
    Key key,
    this.strokeWidth = 2.0,
    @required this.type,
  }) : super(key: key);

  final Color color;

  /// The arrow head is a Equilateral triangle
  final double headSize;

  final double strokeWidth;

  final ArrowType type;

  CustomPainter get _painter => _ArrowPainter(
        arrowHeadSize: headSize,
        color: color,
        strokeWidth: strokeWidth,
        strategy: _ArrowPaintStrategy.strategy(type),
      );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      child: Container(),
    );
  }
}

abstract class _ArrowPaintStrategy {
  void paint({
    @required Canvas canvas,
    @required Size size,
    @required Paint paint,
    @required double headSize,
  });

  static final _ArrowPaintStrategy _up = _UpwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _left = _LeftwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _down = _DownwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _right = _RightwardsArrowPaintStrategy();

  static Path pathForArrowHead(Offset p1, Offset p2, Offset p3) {
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
  }

  static _ArrowPaintStrategy strategy(ArrowType type) {
    switch (type) {
      case ArrowType.up:
        return _up;
      case ArrowType.left:
        return _left;
      case ArrowType.right:
        return _right;
      case ArrowType.down:
        return _down;
      default:
        return _up;
    }
  }
}

class _UpwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final p1 = Offset.zero;
    final p2 = Offset(-arrowHeadSizeDividedByTwo, headSize);
    final p3 = Offset(arrowHeadSizeDividedByTwo, headSize);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
    final lineStartingPoint = Offset(0, headSize);
    final lineEndingPoint = Offset(0, size.height);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
  }
}

class _LeftwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final p1 = Offset.zero;
    final p2 = Offset(headSize, -arrowHeadSizeDividedByTwo);
    final p3 = Offset(headSize, arrowHeadSizeDividedByTwo);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
    final lineStartingPoint = Offset(headSize, 0);
    final lineEndingPoint = Offset(size.width, 0);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
  }
}

class _DownwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final arrowHeadStartingY = size.height - headSize;
    final lineStartingPoint = Offset.zero;
    final lineEndingPoint = Offset(0, arrowHeadStartingY);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
    final p1 = Offset(0, size.height);
    final p2 = Offset(-arrowHeadSizeDividedByTwo, arrowHeadStartingY);
    final p3 = Offset(arrowHeadSizeDividedByTwo, arrowHeadStartingY);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
  }
}

class _RightwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final arrowHeadStartingX = size.width - headSize;
    final lineStartingPoint = Offset.zero;
    final lineEndingPoint = Offset(arrowHeadStartingX, 0);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
    final p1 = Offset(size.width, 0);
    final p2 = Offset(arrowHeadStartingX, -arrowHeadSizeDividedByTwo);
    final p3 = Offset(arrowHeadStartingX, arrowHeadSizeDividedByTwo);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    this.arrowHeadSize = 15.0,
    this.strokeWidth = 2.0,
    this.color = Colors.white,
    this.strategy,
  });

  final double arrowHeadSize;
  final double strokeWidth;
  final Color color;
  final _ArrowPaintStrategy strategy;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    strategy.paint(
      canvas: canvas,
      size: size,
      paint: paint,
      headSize: arrowHeadSize,
    );
  }
}
