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

/// Hardcoded sizes for scaling the flex children widget properly.
const minRenderWidth = 225.0;
const minRenderHeight = 275.0;
const defaultMaxRenderWidth = 300.0;
const defaultMaxRenderHeight = 300.0;

const widgetTitleMaxWidthPercentage = 0.75;

/// Hardcoded arrow size respective to its cross axis (because it's unconstrained).
const heightArrowIndicatorSize = 48.0;
const widthArrowIndicatorSize = 42.0;
const mainAxisArrowIndicatorSize = 32.0;
const crossAxisArrowIndicatorSize = 32.0;

const largeTextScaleFactor = 1.2;
const smallTextScaleFactor = 0.8;

const axisAlignmentAssetImageHeight = 24.0;
const dropdownMaxWidth = 320.0;

String crossAxisAssetImageUrl(CrossAxisAlignment alignment) {
  return 'assets/img/story_of_layout/cross_axis_alignment/${describeEnum(alignment)}.png';
}

/// Compute real widget sizes into rendered sizes to be displayed on the details tab.
/// The sum of the resulting render sizes may or may not be greater than the [maxSizeAvailable]
/// In the case where it is greater, we should render it with scrolling capability.
///
/// if [forceToOccupyMaxSizeAvailable] is set to true,
///   this method will ignore the largestRenderSize
///   and compute it's own largestRenderSize to force
///   the sum of the render size to be equals to [maxSpaceAvailable]
///
/// Formula for computing render size:
///   rs_i = (s_i - ss) * (lrs - srs) / (ls - ss) + srs
/// Variables:
/// - rs_i: render size for element index i
/// - s_i: real size for element at index i (sizes[i])
/// - ss: [smallestSize] (the smallest element in the array [sizes])
/// - ls: [largestSize] (the largest element in the array [sizes])
/// - srs: [smallestRenderSize] (render size for [smallestSize])
/// - lrs: [largestRenderSize] (render size for [largestSize])
/// Explanation:
/// - The computation formula for transforming size to renderSize is based on these two things:
///   - [smallestSize] will be rendered to [smallestRenderSize]
///   - [largestSize] will be rendered to [largestRenderSize]
///   - any other size will be scaled accordingly
/// - The formula above is derived from:
///    (rs_i - srs) / (lrs - srs) = (s_i - ss) / (s - ss)
///
/// Formula for computing forced [largestRenderSize]:
///   lrs = (msa - n * srs) * (ls - ss) / sum(s_i - ss) + srs
/// Variables:
///   - n: [sizes.length]
///   - msa: [maxSizeAvailable]
/// Explanation:
/// - This formula is derived from the equation:
///    sum(rs_i) = msa
///
List<double> computeRenderSizes({
  @required Iterable<double> sizes,
  @required double smallestSize,
  @required double largestSize,
  @required double smallestRenderSize,
  @required double largestRenderSize,
  @required double maxSizeAvailable,
  bool forceToOccupyMaxSizeAvailable = false,
}) {
  /// Assign from parameters and abbreviate variable names for similarity to formula
  final ss = smallestSize, srs = smallestRenderSize;
  final ls = largestSize;
  double lrs = largestRenderSize;
  final msa = maxSizeAvailable;
  final n = sizes.length;

  if (ss == ls) {
    // It means that all widget have the same size
    //   and we can just divide the size evenly
    //   but it should be at least as big as [smallestRenderSize]
    final rs = max(srs, msa / n);
    return [for (var _ in sizes) rs];
  }

  List<double> transformToRenderSize(double lrs) =>
      [for (var s in sizes) (s - ss) * (lrs - srs) / (ls - ss) + srs];

  var renderSizes = transformToRenderSize(largestRenderSize);

  if (forceToOccupyMaxSizeAvailable && sum(renderSizes) < maxSizeAvailable) {
    lrs =
        (msa - n * srs) * (ls - ss) / sum([for (var s in sizes) s - ss]) + srs;
    renderSizes = transformToRenderSize(lrs);
  }
  return renderSizes;
}

String mainAxisAssetImageUrl(MainAxisAlignment alignment) {
  return 'assets/img/story_of_layout/main_axis_alignment/${describeEnum(alignment)}.png';
}

double sum(Iterable<double> numbers) =>
    numbers.fold(0, (sum, cur) => sum + cur);

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

  Widget _visualizeWidthAndHeight({
    @required Widget widget,
    @required LayoutProperties properties,
    double arrowHeadSize = defaultArrowHeadSize,
  }) {
    return BorderLayout(
      center: widget,
      right: Container(
        child: ArrowWrapper.bidirectional(
          arrowColor: heightIndicatorColor,
          arrowStrokeWidth: arrowStrokeWidth,
          arrowHeadSize: arrowHeadSize,
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              '${properties.describeHeight()}\n'
              '(${properties.describeHeightConstraints()})',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.0),
            ),
          ),
          direction: Axis.vertical,
          distanceToArrow: distanceToArrow,
        ),
        margin: const EdgeInsets.only(
          top: margin,
          left: margin,
          bottom: widthArrowIndicatorSize,
        ),
      ),
      rightWidth: heightArrowIndicatorSize,
      bottom: Container(
        child: ArrowWrapper.bidirectional(
          arrowColor: widthIndicatorColor,
          arrowHeadSize: arrowHeadSize,
          arrowStrokeWidth: arrowStrokeWidth,
          child: Text(
            '${properties.describeWidth()}\n'
            '(${properties.describeWidthConstraints()})',
            textAlign: TextAlign.center,
            style: const TextStyle(
              height: 1.0,
            ),
          ),
          direction: Axis.horizontal,
          distanceToArrow: distanceToArrow,
        ),
        margin: const EdgeInsets.only(
          top: margin,
          right: heightArrowIndicatorSize,
          // so that the arrow does not overlap with each other
          bottom: margin,
          left: margin,
        ),
      ),
      bottomHeight: widthArrowIndicatorSize,
    );
  }

  Widget _visualizeFlex(BuildContext context) {
    if (!properties.hasChildren)
      return const Center(child: Text('No Children'));

    final theme = Theme.of(context);

    return _visualizeWidthAndHeight(
      widget: Container(
        margin: const EdgeInsets.only(top: margin, left: margin),
        child: LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          // TODO(albertusangga): Remove ternary checking after visualizing empty space
          final largestRenderWidth = isColumn
              ? maxWidth
              : max(
                  min(
                    maxWidth * properties.largestWidthChildFraction,
                    defaultMaxRenderWidth,
                  ),
                  minRenderWidth,
                );
          // TODO(albertusangga): Remove ternary checking after visualizing empty space
          final largestRenderHeight = isRow
              ? maxHeight
              : max(
                  min(
                    maxHeight * properties.largestHeightChildFraction,
                    defaultMaxRenderHeight,
                  ),
                  minRenderHeight,
                );

          final renderHeights = computeRenderSizes(
            sizes: properties.childrenHeight,
            smallestSize: properties.smallestHeightChild.height,
            largestSize: properties.largestHeightChild.height,
            smallestRenderSize: minRenderHeight,
            largestRenderSize: largestRenderHeight,
            maxSizeAvailable: maxHeight,
            forceToOccupyMaxSizeAvailable: true,
          );

          final renderWidths = computeRenderSizes(
            sizes: properties.childrenWidth,
            smallestSize: properties.smallestWidthChild.width,
            largestSize: properties.largestWidthChild.width,
            smallestRenderSize: minRenderWidth,
            largestRenderSize: largestRenderWidth,
            maxSizeAvailable: maxWidth,
            forceToOccupyMaxSizeAvailable: true,
          );

          return SingleChildScrollView(
            scrollDirection: properties.direction,
            child: Flex(
                mainAxisSize: properties.mainAxisSize,
                direction: properties.direction,
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  for (var i = 0; i < children.length; i++)
                    _visualizeChild(
                      childProperties: children[i],
                      borderColor: i.isOdd ? mainAxisColor : crossAxisColor,
                      textColor: i.isOdd ? null : const Color(0xFF303030),
                      renderHeight: renderHeights[i],
                      renderWidth: renderWidths[i],
                    )
                ]),
          );
        }),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.primaryColorLight,
            width: 1.0,
          ),
        ),
      ),
      properties: properties,
    );
  }

  Widget _visualizeChild({
    LayoutProperties childProperties,
    Color borderColor,
    Color textColor,
    double renderWidth,
    double renderHeight,
  }) {
    final int flexFactor = childProperties.flexFactor;
    return Container(
      width: renderWidth,
      height: renderHeight,
      child: WidgetVisualizer(
        title: childProperties.description,
        borderColor: borderColor,
        textColor: textColor,
        child: _visualizeWidthAndHeight(
          arrowHeadSize: arrowHeadSize,
          widget: Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.only(
                top: margin,
                left: margin,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'flex: $flexFactor',
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
          properties: childProperties,
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
                      maxWidth: minRenderWidth * widgetTitleMaxWidthPercentage),
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
