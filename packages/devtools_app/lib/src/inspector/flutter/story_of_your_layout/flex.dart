// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../ui/colors.dart';
import '../../inspector_text_styles.dart';
import '../inspector_data_models.dart';
import 'arrow.dart';
import 'utils.dart';

const widthIndicatorColor = mainUiColor;
const heightIndicatorColor = mainGpuColor;

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

  Size get size => properties.size;

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
    Color textColor,
    Size parentSize,
    Size screenSize,
  }) {
    final size = node.size;
    final int flexFactor = node.flexFactor;

    const rightWidth = 16.0;

    final child = WidgetVisualizer(
      title: node.description,
//      hint: Container(
//        padding: const EdgeInsets.all(4.0),
//        child: Column(
//          mainAxisAlignment: MainAxisAlignment.start,
//          crossAxisAlignment: CrossAxisAlignment.end,
//          children: <Widget>[
//            Text(
//              'flex: ${node.flexFactor}',
//              style: TextStyle(fontWeight: FontWeight.bold),
//            ),
//            if (flexFactor == 0 || flexFactor == null)
//              Text(
//                'unconstrained ${isRow ? 'horizontal' : 'vertical'}',
//                style: regularItalic.merge(warning),
//                maxLines: 2,
//                softWrap: true,
//                overflow: TextOverflow.ellipsis,
//                textScaleFactor: 0.8,
//                textAlign: TextAlign.right,
//              ),
//          ],
//        ),
//      ),
      borderColor: borderColor,
      textColor: textColor,
      child: BorderLayout(
          topHeight: 16.0,
          right: Container(
            child: ArrowWrapper.bidirectional(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text('height: ${size.height}'),
              ),
              direction: Axis.vertical,
              arrowHeadSize: 8.0,
              distanceToArrow: 1.0,
              arrowColor: heightIndicatorColor,
            ),
            width: rightWidth,
            margin: const EdgeInsets.only(bottom: 16.0),
          ),
          rightWidth: rightWidth,
          bottom: Container(
            child: ArrowWrapper.bidirectional(
              child: Text('width: ${size.width.toStringAsFixed(1)}'),
              direction: Axis.horizontal,
              arrowHeadSize: 8.0,
              arrowColor: widthIndicatorColor,
            ),
            height: 16.0,
            margin: const EdgeInsets.only(left: 8.0, right: 10.0),
          ),
          bottomHeight: 16.0,
          center: Container(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'flex: ${node.flexFactor}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (flexFactor == 0 || flexFactor == null)
                  Text(
                    'unconstrained ${isRow ? 'horizontal' : 'vertical'}',
                    style: regularItalic.merge(warning),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textScaleFactor: 0.8,
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          )),
    );

    final smallestWidthPercentage = smallestWidth / parentSize.width;
    final smallestHeightPercentage = smallestHeight / parentSize.height;
    final largestWidthPercentage = largestWidth / parentSize.width;
    final largestHeightPercentage = largestHeight / parentSize.height;

    final widthDifference =
        largestWidth == smallestWidth ? 1 : (largestWidth - smallestWidth);
    final heightDifference =
        largestHeight == smallestHeight ? 1 : (largestHeight - smallestHeight);

    final smallestWidthOnScreen =
        max(170, screenSize.width * smallestWidthPercentage);
    final smallestHeightOnScreen =
        max(150, screenSize.height * smallestHeightPercentage);
    final largestWidthOnScreen =
        screenSize.width * (isRow ? largestWidthPercentage : 1);
    final largestHeightOnScreen =
        screenSize.height * (isRow ? 1 : largestHeightPercentage);

    final width = (size.width - smallestWidth) *
            (largestWidthOnScreen - smallestWidthOnScreen) /
            widthDifference +
        smallestWidthOnScreen;
    final height = (size.height - smallestHeight) *
            (largestHeightOnScreen - smallestHeightOnScreen) /
            heightDifference +
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
                  borderColor: i.isOdd ? mainAxisColor : crossAxisColor,
                  textColor: i.isOdd ? null : const Color(0xFF303030),
                  parentSize: size,
                  screenSize: Size(width, height),
                )
            ],
          ),
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.primaryColorLight,
            width: 1.0,
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
    return BorderLayout(
      center: child,
      leftWidth: left + margin,
      rightWidth: right + margin,
      bottomHeight: bottom + margin,
      topHeight: top + margin,
      right: Container(
        child: ArrowWrapper.bidirectional(
          arrowColor: heightIndicatorColor,
          arrowStrokeWidth: 1.5,
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              'height: ${size.height.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
            ),
          ),
          direction: Axis.vertical,
        ),
        width: right,
        height: height - bottom - top - 2 * margin,
        margin: const EdgeInsets.only(left: margin),
      ),
      bottom: Container(
        margin: const EdgeInsets.only(top: margin),
        child: ArrowWrapper.bidirectional(
          arrowColor: widthIndicatorColor,
          arrowStrokeWidth: 1.5,
          child: Text(
            'width: ${size.width}',
            textAlign: TextAlign.center,
          ),
          direction: Axis.horizontal,
        ),
        width: width - right - left - 2 * margin,
        height: bottom,
      ),
      top: Text(
        properties.direction == Axis.horizontal
            ? mainAxisAlignment.toString()
            : crossAxisAlignment.toString(),
        textScaleFactor: 1.25,
      ),
      left: RotatedBox(
        quarterTurns: 3,
        child: Text(
          properties.direction == Axis.vertical
              ? mainAxisAlignment.toString()
              : crossAxisAlignment.toString(),
          textScaleFactor: 1.25,
        ),
      ),
    );
  }

  Color get horizontalColor =>
      properties.isHorizontalMainAxis ? mainAxisColor : crossAxisColor;

  Color get verticalColor =>
      properties.isVerticalMainAxis ? mainAxisColor : crossAxisColor;

  String get flexType => properties.type.toString();

  Widget _buildAxisAlignmentDropdown(Axis axis) {
    Color color;
    String axisDescription;
    List<Object> alignmentEnumEntries;
    Object selected;
    if (axis == Axis.horizontal) {
      color = horizontalColor;
      axisDescription = properties.horizontalDirectionDescription;
    } else {
      color = verticalColor;
      axisDescription = properties.verticalDirectionDescription;
    }
    if (axis == direction) {
      alignmentEnumEntries = MainAxisAlignment.values;
      selected = mainAxisAlignment;
    } else {
      alignmentEnumEntries = CrossAxisAlignment.values;
      selected = crossAxisAlignment;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$axisDescription Alignment: ',
          textScaleFactor: 1.2,
        ),
        Container(
          margin: const EdgeInsets.only(left: 8.0),
          child: DropdownButton(
            itemHeight: 80,
            value: selected,
            items: [
              for (var alignment in alignmentEnumEntries)
                DropdownMenuItem(
                  value: alignment,
                  child: Container(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          describeEnum(alignment) + ':',
                          style: TextStyle(
                            color: color,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8.0),
                          child: Image.asset(
                            (axis == direction)
                                ? getMainAxisAssetImageUrl(alignment)
                                : getCrossAxisAssetImageUrl(alignment),
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
            ],
            onChanged: (Object newSelection) {
              setState(() {
                if (axis == direction) {
                  mainAxisAlignment = newSelection;
                } else {
                  crossAxisAlignment = newSelection;
                }
              });
            },
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Align(
            alignment: Alignment.centerRight,
            child: _buildAxisAlignmentDropdown(Axis.horizontal),
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
                          title: flexType,
                          hint: Container(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              'Total Flex Factor: ${properties.totalFlex}',
                              textScaleFactor: 1.2,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          borderColor: mainAxisColor,
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
                          arrowColor: verticalColor,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              properties.verticalDirectionDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: verticalColor,
                              ),
                            ),
                          ),
                          type: ArrowType.down,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        height: topArrowIndicatorHeight,
                        width: maxWidth - leftArrowIndicatorWidth - margin,
                        child: ArrowWrapper.unidirectional(
                          arrowColor: horizontalColor,
                          child: FittedBox(
                            child: Text(
                              properties.horizontalDirectionDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: horizontalColor,
                              ),
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
          Align(
            alignment: Alignment.centerLeft,
            child: _buildAxisAlignmentDropdown(Axis.vertical),
          ),
        ],
      ),
    );
  }
}

class WidgetVisualizer extends StatelessWidget {
  const WidgetVisualizer({
    Key key,
    @required this.title,
    @required this.hint,
    @required this.borderColor,
    @required this.textColor,
    this.child,
  })  : assert(title != null),
        assert(borderColor != null),
        super(key: key);

  final String title;
  final Widget child;
  final Widget hint;

  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints(maxWidth: 75.0),
                  child: Center(
                    child: Text(
                      title,
                      textScaleFactor: 1.0,
                      style: textColor != null
                          ? TextStyle(
                              color: textColor,
                            )
                          : null,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: borderColor,
                  ),
                  padding: const EdgeInsets.all(4.0),
                ),
                if (hint != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: hint,
                    ),
                  ),
              ],
            ),
          ),
          if (child != null)
            Expanded(
              child: child,
            ),
        ],
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
      ),
      margin: const EdgeInsets.all(1.0),
    );
  }
}

String getMainAxisAssetImageUrl(MainAxisAlignment alignment) {
  return 'assets/img/story_of_layout/main_axis_alignment/${describeEnum(alignment)}.png';
}

String getCrossAxisAssetImageUrl(CrossAxisAlignment alignment) {
  return 'assets/img/story_of_layout/cross_axis_alignment/${describeEnum(alignment)}.png';
}
