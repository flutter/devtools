// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../ui/colors.dart';
import '../../../ui/theme.dart';
import '../inspector_data_models.dart';
import 'arrow.dart';
import 'utils.dart';

const widthIndicatorColor = mainUiColor;
const heightIndicatorColor = mainGpuColor;
const margin = 8.0;

const arrowHeadSize = 8.0;
const distanceToArrow = 1.0;
const arrowStrokeWidth = 1.5;

/// Minimum size for scaling the flex children widget properly
const renderedMinWidth = 175.0;
const renderedMinHeight = 150.0;

const widgetTitleMaxWidthPercentage = 0.75;

/// Hardcoded arrow size respective to its cross axis (because it's unconstrained)
const outerHeightArrowIndicatorSize = 24.0;
const outerWidthArrowIndicatorSize = 24.0;
const innerHeightArrowIndicatorSize = 16.0;
const innerWidthArrowIndicatorSize = 16.0;
const mainAxisArrowIndicatorSize = 32.0;
const crossAxisArrowIndicatorSize = 32.0;

const largeTextScaleFactor = 1.2;
const smallTextScaleFactor = 0.8;

const axisAlignmentAssetImageHeight = 24.0;
const dropdownMaxWidth = 320.0;

String crossAxisAssetImageUrl(CrossAxisAlignment alignment) {
  return 'assets/img/story_of_layout/cross_axis_alignment/${describeEnum(alignment)}.png';
}

String mainAxisAssetImageUrl(MainAxisAlignment alignment) {
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

    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final maxSize = Size(constraints.maxWidth, constraints.maxHeight);
      final renderSmallestWidth = max(renderedMinWidth,
          maxSize.width * properties.smallestWidthChildPercentage);
      final renderSmallestHeight = max(renderedMinHeight,
          maxSize.height * properties.smallestHeightChildPercentage);
      final renderLargestWidth =
          maxSize.width * (isRow ? properties.largestWidthChildPercentage : 1);
      final renderLargestHeight = maxSize.height *
          (isRow ? 1 : properties.largestHeightChildPercentage);

      return BorderLayout(
        center: Container(
          margin: const EdgeInsets.only(top: margin * 2, left: margin * 2),
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
            arrowStrokeWidth: arrowStrokeWidth,
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                'height: ${size.height.toStringAsFixed(1)}',
                textAlign: TextAlign.center,
              ),
            ),
            direction: Axis.vertical,
          ),
          height: maxSize.height - outerWidthArrowIndicatorSize - margin,
          margin: const EdgeInsets.only(left: margin),
        ),
        rightWidth: outerHeightArrowIndicatorSize,
        bottom: Container(
          margin: const EdgeInsets.only(top: margin),
          child: ArrowWrapper.bidirectional(
            arrowColor: widthIndicatorColor,
            arrowStrokeWidth: arrowStrokeWidth,
            child: Text(
              'width: ${size.width}',
              textAlign: TextAlign.center,
            ),
            direction: Axis.horizontal,
          ),
          width: maxSize.width - outerHeightArrowIndicatorSize - margin,
        ),
        bottomHeight: outerWidthArrowIndicatorSize,
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
    // TODO(albertusangga): Refactor computation of width & height to share same helper
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
              arrowHeadSize: arrowHeadSize,
              arrowColor: heightIndicatorColor,
              distanceToArrow: distanceToArrow,
            ),
            margin:
                const EdgeInsets.only(bottom: innerHeightArrowIndicatorSize),
          ),
          rightWidth: innerWidthArrowIndicatorSize,
          bottom: Container(
            child: ArrowWrapper.bidirectional(
              child: Text('width: ${size.width.toStringAsFixed(1)}'),
              direction: Axis.horizontal,
              arrowHeadSize: arrowHeadSize,
              arrowColor: widthIndicatorColor,
              distanceToArrow: distanceToArrow,
            ),
            margin: const EdgeInsets.symmetric(horizontal: margin),
          ),
          bottomHeight: innerHeightArrowIndicatorSize,
          top: Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              margin: const EdgeInsets.only(
                  right: innerWidthArrowIndicatorSize + margin),
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
                      style: TextStyle(
                        color: ThemedColor(
                          const Color(0xFFD08A29),
                          Colors.orange.shade700,
                        ),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textScaleFactor: smallTextScaleFactor,
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
    return Container(
      constraints: const BoxConstraints(maxWidth: dropdownMaxWidth),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$axisDescription Alignment: ',
            textScaleFactor: largeTextScaleFactor,
          ),
          Container(
            margin: const EdgeInsets.only(left: 8.0),
            child: DropdownButton(
              isExpanded: true,
              value: selected,
              items: [
                for (var alignment in alignmentEnumEntries)
                  DropdownMenuItem(
                    value: alignment,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              describeEnum(alignment),
                              style: TextStyle(color: color),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        Image.asset(
                          (axis == direction)
                              ? mainAxisAssetImageUrl(alignment)
                              : crossAxisAssetImageUrl(alignment),
                          height: axisAlignmentAssetImageHeight,
                          fit: BoxFit.contain,
                        ),
                      ],
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
      ),
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
            child: Container(
              margin: const EdgeInsets.all(margin),
              child: LayoutBuilder(builder: (context, constraints) {
                final maxHeight = constraints.maxHeight;
                final maxWidth = constraints.maxWidth;
                return Container(
                  constraints:
                      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                  child: Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(
                            top: mainAxisArrowIndicatorSize,
                            left: crossAxisArrowIndicatorSize + margin,
                          ),
                          child: WidgetVisualizer(
                            title: flexType,
                            hint: Container(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                'Total Flex Factor: ${properties?.totalFlex}',
                                textScaleFactor: largeTextScaleFactor,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            borderColor: mainAxisColor,
                            child: Container(
                              margin: const EdgeInsets.only(
                                /// margin for the outer width/height
                                ///  so that they don't stick to the corner
                                right: margin,
                                bottom: margin,
                              ),
                              child: _visualizeFlex(context),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: maxHeight - mainAxisArrowIndicatorSize,
                          width: crossAxisArrowIndicatorSize,
                          child: ArrowWrapper.unidirectional(
                            arrowColor: verticalColor,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                properties.verticalDirectionDescription,
                                textAlign: TextAlign.center,
                                textScaleFactor: largeTextScaleFactor,
                              ),
                            ),
                            type: ArrowType.down,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          height: mainAxisArrowIndicatorSize,
                          width:
                              maxWidth - crossAxisArrowIndicatorSize - margin,
                          child: ArrowWrapper.unidirectional(
                            arrowColor: horizontalColor,
                            child: FittedBox(
                              child: Text(
                                properties.horizontalDirectionDescription,
                                textAlign: TextAlign.center,
                                textScaleFactor: largeTextScaleFactor,
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

/// Widget that draws bounding box with the title (usually widget name) in its top left
///
/// [hint] is an optional widget to be placed in the top right of the box
/// [child] is an optional widget to be placed in the center of the box
/// [borderColor] outer box border color and background color for the title
/// [textColor] color for title text
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
                  constraints: const BoxConstraints(
                      maxWidth:
                          renderedMinWidth * widgetTitleMaxWidthPercentage),
                  child: Center(
                    child: Text(
                      title,
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
