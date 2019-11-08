// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../ui/colors.dart';
import '../../inspector_text_styles.dart';
import '../inspector_data_models.dart';
import 'arrow.dart';

class StoryOfYourFlexWidget extends StatefulWidget {
  const StoryOfYourFlexWidget(
    this.properties, {
    Key key,
  })  : assert(properties != null),
        super(key: key);

  final FlexLayoutProperties properties;

  @override
  _StoryOfYourFlexWidgetState createState() => _StoryOfYourFlexWidgetState();
}

class _StoryOfYourFlexWidgetState extends State<StoryOfYourFlexWidget> {
  int totalFlexFactor;
  MainAxisAlignment mainAxisAlignment;
  CrossAxisAlignment crossAxisAlignment;

  double smallestWidth, largestWidth;
  double smallestHeight, largestHeight;

  Size get size => widget.properties.size;

  FlexLayoutProperties get properties => widget.properties;

  List<LayoutProperties> get children => widget.properties.childrenProperties;

  Axis get direction => widget.properties.direction;

  bool get isRow => properties.direction == Axis.horizontal;

  bool get isColumn => !isRow;

  void _update() {
    totalFlexFactor = properties.totalFlex;
    mainAxisAlignment = properties.mainAxisAlignment;
    crossAxisAlignment = properties.crossAxisAlignment;

    final childrenWidths = children
        .where((child) => child.size.width != null)
        .map((child) => child.size.width);
    final childrenHeights = children
        .where((child) => child.size.height != null)
        .map((child) => child.size.height);
    smallestWidth = childrenWidths.reduce(min);
    largestWidth = childrenWidths.reduce(max);
    smallestHeight = childrenHeights.reduce(min);
    largestHeight = childrenHeights.reduce(max);
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  Widget _visualizeChild({
    Key key,
    LayoutProperties node,
    Color borderColor,
    Color backgroundColor,
    Size parentSize,
    Size screenSize,
  }) {
    final size = node.size;
    final int flexFactor = node.flexFactor;

    final unconstrained = flexFactor == 0 || flexFactor == null;
    final child = WidgetVisualizer(
      widgetName: node.description,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              child: ArrowWrapper.bidirectional(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text('height: ${size.height}'),
                ),
                direction: Axis.vertical,
                arrowHeadSize: 8.0,
              ),
              width: 16.0,
              margin: const EdgeInsets.only(bottom: 16.0),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(builder: (context, constraints) {
              return Container(
                child: ArrowWrapper.bidirectional(
                  child: Text('width: ${size.width}'),
                  direction: Axis.horizontal,
                  arrowHeadSize: 8.0,
                ),
                height: 16.0,
                margin: const EdgeInsets.only(left: 20.0, right: 8.0),
              );
            }),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'flex: $flexFactor',
                    style: regularBold,
                    textAlign: TextAlign.center,
                  ),
                  if (unconstrained)
                    Text(
                      'unconstrained',
                      style: error,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final smallestWidthPercentage = smallestWidth / parentSize.width;
    final smallestHeightPercentage = smallestHeight / parentSize.height;
    final largestWidthPercentage = largestWidth / parentSize.width;
    final largestHeightPercentage = largestHeight / parentSize.height;

    final smallestWidthOnScreen =
        max(150, screenSize.width * smallestWidthPercentage);
    final smallestHeightOnScreen =
        max(150, screenSize.height * smallestHeightPercentage);
    final largestWidthOnScreen =
        screenSize.width * (isRow ? largestWidthPercentage : 1);
    final largestHeightOnScreen =
        screenSize.height * (isRow ? 1 : largestHeightPercentage);

    final width = (size.width - smallestWidth) *
            (largestWidthOnScreen - smallestWidthOnScreen) /
            (largestWidth - smallestWidth) +
        smallestWidthOnScreen;
    final height = (size.height - smallestHeight) *
            (largestHeightOnScreen - smallestHeightOnScreen) /
            (largestHeight - smallestHeight) +
        smallestHeightOnScreen;
    return Container(
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _visualizeFlex(BuildContext context) {
    if (!properties.hasChildren)
      return const Center(child: Text('No Children'));
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final flex = Container(
        width: width,
        height: height,
        child: SingleChildScrollView(
          scrollDirection: properties.direction,
          child: Flex(
            mainAxisSize: properties.mainAxisSize,
            direction: properties.direction,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (var i = 0; i < children.length; i++)
                _visualizeChild(
                  node: children[i],
                  borderColor: i.isOdd ? mainGpuColor : mainUiColor,
                  backgroundColor: theme.backgroundColor,
                  parentSize: size,
                  screenSize: Size(width, height),
                )
            ],
          ),
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.accentColor,
            width: 2.0,
          ),
        ),
      );
      return _visualizeMainAxisAndCrossAxis(
        child: flex,
        width: width,
        height: height,
        theme: theme,
      );
    });
  }

  Widget _visualizeMainAxisAndCrossAxis({
    Widget child,
    double width,
    double height,
    ThemeData theme,
  }) {
    const right = 16.0;
    const bottom = 16.0;
    const top = 16.0;
    const left = 16.0;
    const margin = 8.0;
//    // TODO(albertusangga): Fix borderlayout
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.only(
                right: right + margin,
                bottom: bottom + margin,
                top: top + margin,
                left: left + margin),
            child: child,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            child: ArrowWrapper.bidirectional(
              arrowColor: theme.splashColor,
              arrowStrokeWidth: 1.0,
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'height: ${size.height} px',
                  textAlign: TextAlign.center,
                ),
              ),
              direction: Axis.vertical,
            ),
            width: right,
            height: height - bottom - top - 2 * margin,
            margin: const EdgeInsets.only(left: margin),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(top: margin),
            child: ArrowWrapper.bidirectional(
              arrowColor: theme.splashColor,
              arrowStrokeWidth: 1.0,
              child: Text(
                'width: ${size.width} px',
                textAlign: TextAlign.center,
              ),
              direction: Axis.horizontal,
            ),
            width: width - right - left - 2 * margin,
            height: bottom,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Text(
            widget.properties.direction == Axis.horizontal
                ? mainAxisAlignment.toString()
                : crossAxisAlignment.toString(),
            textScaleFactor: 1.25,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
                widget.properties.direction == Axis.vertical
                    ? mainAxisAlignment.toString()
                    : crossAxisAlignment.toString(),
                textScaleFactor: 1.25),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Container(
            child: Text(
              'Total Flex Factor: ${widget.properties.totalFlex}',
              textScaleFactor: 1.25,
            ),
            margin: const EdgeInsets.only(right: right + margin),
          ),
        ),
      ],
      overflow: Overflow.visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flexType = widget.properties.type.toString();
    final theme = Theme.of(context);
    final direction = widget.properties.direction;
    final horizontalDirectionAlignments = direction == Axis.horizontal
        ? MainAxisAlignment.values
        : CrossAxisAlignment.values;
    final verticalDirectionAlignments = direction == Axis.vertical
        ? MainAxisAlignment.values
        : CrossAxisAlignment.values;
    return Container(
      padding: const EdgeInsets.only(top: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(widget.properties.horizontalDirectionDescription + ': '),
              DropdownButton(
                value: direction == Axis.horizontal
                    ? mainAxisAlignment
                    : crossAxisAlignment,
                items: [
                  for (var alignment in horizontalDirectionAlignments)
                    DropdownMenuItem(
                      value: alignment,
                      child: Text(alignment.toString()),
                    )
                ],
                onChanged: (newValue) {
                  if (direction == Axis.horizontal) {
                    mainAxisAlignment = newValue;
                  } else {
                    crossAxisAlignment = newValue;
                  }
                  setState(() {});
                },
              )
            ],
          ),
          Flexible(
            child: LayoutBuilder(builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.95;
              final maxWidth = constraints.maxWidth * 0.95;
              const topArrowIndicatorHeight = 32.0;
              const leftArrowIndicatorWidth = 32.0;
              const margin = 8.0;
              return Container(
                constraints:
                    BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          top: topArrowIndicatorHeight,
                          left: leftArrowIndicatorWidth + margin,
                        ),
                        child: WidgetVisualizer(
                          widgetName: flexType,
                          borderColor: theme.accentColor,
                          backgroundColor: theme.primaryColor,
                          child: Container(
                            margin: const EdgeInsets.only(
                              left: 8.0,
                              right: 8.0,
                              bottom: 8.0,
                            ),
                            child: _visualizeFlex(context),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        height: maxHeight - topArrowIndicatorHeight,
                        width: leftArrowIndicatorWidth,
                        child: ArrowWrapper.unidirectional(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              widget.properties.verticalDirectionDescription,
                              textAlign: TextAlign.center,
                              style: regularBold,
                            ),
                          ),
                          type: ArrowType.down,
                          arrowColor: theme.primaryColorLight,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        height: topArrowIndicatorHeight,
                        width: maxWidth - leftArrowIndicatorWidth - margin,
                        child: ArrowWrapper.unidirectional(
                          child: FittedBox(
                            child: Text(
                              widget.properties.horizontalDirectionDescription,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          type: ArrowType.right,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              DropdownButton(
                value: direction == Axis.vertical
                    ? mainAxisAlignment
                    : crossAxisAlignment,
                items: [
                  for (var alignment in verticalDirectionAlignments)
                    DropdownMenuItem(
                      value: alignment,
                      child: Text(alignment.toString()),
                    )
                ],
                onChanged: (newValue) {
                  if (direction == Axis.vertical) {
                    mainAxisAlignment = newValue;
                  } else {
                    crossAxisAlignment = newValue;
                  }
                  setState(() {});
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}

class WidgetVisualizer extends StatelessWidget {
  const WidgetVisualizer({
    Key key,
    @required this.widgetName,
    @required this.borderColor,
    @required this.backgroundColor,
    this.child,
  })  : assert(widgetName != null),
        assert(borderColor != null),
        assert(backgroundColor != null),
        super(key: key);

  final String widgetName;
  final Color borderColor;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: Text(widgetName),
            decoration: BoxDecoration(
              color: borderColor,
            ),
            padding: const EdgeInsets.all(4.0),
          ),
          if (child != null)
            Flexible(
              child: child,
            ),
        ],
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
        color: backgroundColor,
      ),
    );
  }
}
