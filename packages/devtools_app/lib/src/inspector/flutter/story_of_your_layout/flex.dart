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

String getCrossAxisAssetImageUrl(CrossAxisAlignment alignment) {
  return 'assets/img/story_of_layout/cross_axis_alignment/${describeEnum(alignment)}.png';
}

String getMainAxisAssetImageUrl(MainAxisAlignment alignment) {
  return 'assets/img/story_of_layout/main_axis_alignment/${describeEnum(alignment)}.png';
}

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
  static const kBottomHeight = 16.0;
  static const kRightWidth = 16.0;
  static const kArrowHeadSize = 8.0;
  static const kDistanceToArrow = 1.0;
  static const kMargin = 8.0;
  static const kRenderedMinWidth = 175.0;
  static const kRenderedMinHeight = 150.0;

  int totalFlexFactor;
  MainAxisAlignment mainAxisAlignment;
  CrossAxisAlignment crossAxisAlignment;

  Size get size => properties.size;

  FlexLayoutProperties get properties => widget.properties;

  List<LayoutProperties> get children => widget.properties.children;

  Axis get direction => widget.properties.direction;

  bool get isRow => properties.direction == Axis.horizontal;

  bool get isColumn => !isRow;

  Color get horizontalColor =>
      properties.isHorizontalMainAxis ? mainAxisColor : crossAxisColor;

  Color get verticalColor =>
      properties.isVerticalMainAxis ? mainAxisColor : crossAxisColor;

  String get flexType => properties.type.toString();

  void _update() {
    totalFlexFactor = properties.totalFlex;
    mainAxisAlignment = properties.mainAxisAlignment;
    crossAxisAlignment = properties.crossAxisAlignment;
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

  Widget _visualizeFlex(BuildContext context) {
    if (!properties.hasChildren)
      return const Center(child: Text('No Children'));

    const kHeightArrowIndicatorWidth = 32.0;
    const kWidthArrowIndicatorHeight = 32.0;
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
      final renderSmallestWidth = max(kRenderedMinWidth,
          screenSize.width * properties.smallestWidthChildPercentage);
      final renderSmallestHeight = max(kRenderedMinHeight,
          screenSize.height * properties.smallestHeightChildPercentage);
      final renderLargestWidth = screenSize.width *
          (isRow ? properties.largestWidthChildPercentage : 1);
      final renderLargestHeight = screenSize.height *
          (isRow ? 1 : properties.largestHeightChildPercentage);

      return BorderLayout(
        center: Container(
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
                    renderSmallestHeight: renderSmallestHeight,
                    renderLargestHeight: renderLargestHeight,
                    renderSmallestWidth: renderSmallestWidth,
                    renderLargestWidth: renderLargestWidth,
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
        ),
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
          height: screenSize.height - kWidthArrowIndicatorHeight - kMargin,
          margin: const EdgeInsets.only(left: kMargin),
        ),
        rightWidth: kHeightArrowIndicatorWidth,
        bottom: Container(
          margin: const EdgeInsets.only(top: kMargin),
          child: ArrowWrapper.bidirectional(
            arrowColor: widthIndicatorColor,
            arrowStrokeWidth: 1.5,
            child: Text(
              'width: ${size.width}',
              textAlign: TextAlign.center,
            ),
            direction: Axis.horizontal,
          ),
          width: screenSize.width - kHeightArrowIndicatorWidth - kMargin,
        ),
        bottomHeight: kWidthArrowIndicatorHeight,
      );
    });
  }

  Widget _visualizeChild({
    LayoutProperties node,
    Color borderColor,
    Color textColor,
    double renderSmallestWidth,
    double renderSmallestHeight,
    double renderLargestWidth,
    double renderLargestHeight,
  }) {
    final size = node.size;
    final width = size.width;
    final height = size.height;

    final smallestWidth = properties.smallestWidthChild.size.width;
    final smallestHeight = properties.smallestHeightChild.size.height;
    final largestWidth = properties.largestWidthChild.size.width;
    final largestHeight = properties.largestHeightChild.size.height;

    final widthDifference =
        largestWidth == smallestWidth ? 1 : (largestWidth - smallestWidth);
    final heightDifference =
        largestHeight == smallestHeight ? 1 : (largestHeight - smallestHeight);

    final renderWidthDiff = renderLargestWidth - renderSmallestWidth;
    final renderHeightDiff = renderLargestHeight - renderSmallestHeight;

    final renderWidth =
        (width - smallestWidth) * renderWidthDiff / widthDifference +
            renderSmallestWidth;
    final renderHeight =
        (height - smallestHeight) * renderHeightDiff / heightDifference +
            renderSmallestHeight;

    final int flexFactor = node.flexFactor;
    return Container(
      width: renderWidth,
      height: renderHeight,
      child: WidgetVisualizer(
        title: node.description,
        borderColor: borderColor,
        textColor: textColor,
        child: BorderLayout(
          right: Container(
            child: ArrowWrapper.bidirectional(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text('height: ${size.height}'),
              ),
              direction: Axis.vertical,
              arrowHeadSize: kArrowHeadSize,
              arrowColor: heightIndicatorColor,
              distanceToArrow: kDistanceToArrow,
            ),
            margin: const EdgeInsets.only(bottom: kBottomHeight),
          ),
          rightWidth: kRightWidth,
          bottom: Container(
            child: ArrowWrapper.bidirectional(
              child: Text('width: ${size.width.toStringAsFixed(1)}'),
              direction: Axis.horizontal,
              arrowHeadSize: kArrowHeadSize,
              arrowColor: widthIndicatorColor,
              distanceToArrow: kDistanceToArrow,
            ),
            margin: const EdgeInsets.symmetric(horizontal: kMargin),
          ),
          bottomHeight: kBottomHeight,
          top: Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              margin: const EdgeInsets.only(right: kRightWidth + kMargin),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
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
            ),
          ),
        ),
      ),
    );
  }

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
            itemHeight: 64,
            value: selected,
            items: [
              for (var alignment in alignmentEnumEntries)
                DropdownMenuItem(
                  value: alignment,
                  child: Container(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                              textScaleFactor: 1.2,
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
                              textScaleFactor: 1.2,
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
          Container(
            margin: const EdgeInsets.only(left: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildAxisAlignmentDropdown(Axis.vertical),
            ),
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
    this.hint,
    @required this.borderColor,
    this.textColor,
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
                  constraints: const BoxConstraints(maxWidth: 125.0),
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
                  Flexible(
                    child: hint,
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
