// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../utils.dart';
import '../diagnostics_node.dart';
import '../enum_utils.dart';
import 'story_of_your_layout/utils.dart';

const Type boxConstraintsType = BoxConstraints;

/// Compute real widget sizes into rendered sizes to be displayed on the details tab.
/// The sum of the resulting render sizes may or may not be greater than the [maxSizeAvailable]
/// In the case where it is greater, we should render it with scrolling capability.
///
/// Variables:
/// - [sizes] : real size for widgets that want to be rendered / scaled
/// - [smallestSize] : the smallest element in the array [sizes]
/// - [largestSize] : the largest element in the array [sizes]
/// - [smallestRenderSize] : render size for smallest element
/// - [largestRenderSize] : render size for largest element
/// - [maxSizeAvailable] : maximum size available for rendering the widget
/// - [useMaxSizeAvailable] : flag for forcing the widget dimension to be at least [maxSizeAvailable]
///
/// if [useMaxSizeAvailable] is set to true,
/// this method will ignore the largestRenderSize
/// and compute it's own largestRenderSize to force
/// the sum of the render size to be equals to [maxSizeAvailable]
///
/// Formula for computing render size:
///   renderSize[i] = (size[i] - smallestSize)
///               * (largestRenderSize - smallestRenderSize)
///               / (largestSize - smallestSize) + smallestRenderSize
/// Explanation:
/// - The computation formula for transforming size to renderSize is based on these two things:
///   - smallest element will be rendered to [smallestRenderSize]
///   - largest element will be rendered to [largestRenderSize]
///   - any other size will be scaled accordingly
/// - The formula above is derived from:
///    (renderSize[i] - smallestRenderSize) / (largestRenderSize - smallestRenderSize)
///     = (size[i] - smallestSize) / (size[i] - smallestSize)
///
/// Formula for computing forced [largestRenderSize]:
///   largestRenderSize = (maxSizeAvailable - sizes.length * smallestRenderSize)
///     * (largestSize - smallestSize) / sum(s[i] - ss) + smallestRenderSize
/// Explanation:
/// - This formula is derived from the equation:
///    sum(renderSize) = maxSizeAvailable
///
List<double> computeRenderSizes({
  @required Iterable<double> sizes,
  @required double smallestSize,
  @required double largestSize,
  @required double smallestRenderSize,
  @required double largestRenderSize,
  @required double maxSizeAvailable,
  bool useMaxSizeAvailable = true,
}) {
  final n = sizes.length;

  if (smallestSize == largestSize) {
    // It means that all widget have the same size
    // and we can just divide the size evenly
    // but it should be at least as big as [smallestRenderSize]
    final renderSize = math.max(smallestRenderSize, maxSizeAvailable / n);
    return [for (var _ in sizes) renderSize];
  }

  List<double> transformToRenderSize(double largestRenderSize) => [
        for (var s in sizes)
          (s - smallestSize) *
                  (largestRenderSize - smallestRenderSize) /
                  (largestSize - smallestSize) +
              smallestRenderSize
      ];

  var renderSizes = transformToRenderSize(largestRenderSize);

  if (useMaxSizeAvailable && sum(renderSizes) < maxSizeAvailable) {
    largestRenderSize = (maxSizeAvailable - n * smallestRenderSize) *
            (largestSize - smallestSize) /
            sum([for (var s in sizes) s - smallestSize]) +
        smallestRenderSize;
    renderSizes = transformToRenderSize(largestRenderSize);
  }
  return renderSizes;
}

double computeSpaceBeforeChildren({
  @required MainAxisAlignment mainAxisAlignment,
  @required double freeSpace,
  @required int childrenLength,
}) {
  if (childrenLength == 0) return 0.0;
  switch (mainAxisAlignment) {
    case MainAxisAlignment.start:
      return 0.0;
    case MainAxisAlignment.end:
      return freeSpace;
    case MainAxisAlignment.center:
      return freeSpace * 0.5;
    case MainAxisAlignment.spaceBetween:
      return 0.0;
    case MainAxisAlignment.spaceAround:
      final spaceBetweenChildren = freeSpace / childrenLength;
      return spaceBetweenChildren * 0.5;
    case MainAxisAlignment.spaceEvenly:
      return freeSpace / (childrenLength + 1);
    default:
      return 0.0;
  }
}

double computeSpaceAfterChildren({
  @required MainAxisAlignment mainAxisAlignment,
  @required double freeSpace,
  @required int childrenLength,
}) {
  if (childrenLength == 0) return 0.0;
  switch (mainAxisAlignment) {
    case MainAxisAlignment.start:
      return freeSpace;
    case MainAxisAlignment.end:
      return 0.0;
    case MainAxisAlignment.center:
      return freeSpace * 0.5;
    case MainAxisAlignment.spaceBetween:
      return 0.0;
    case MainAxisAlignment.spaceAround:
      final spaceBetweenChildren = freeSpace / childrenLength;
      return spaceBetweenChildren * 0.5;
    case MainAxisAlignment.spaceEvenly:
      return freeSpace / (childrenLength + 1);
    default:
      return 0.0;
  }
}

double computeSpaceBetweenChildren({
  @required MainAxisAlignment mainAxisAlignment,
  @required double freeSpace,
  @required int childrenLength,
}) {
  if (childrenLength == 0) return 0.0;
  switch (mainAxisAlignment) {
    case MainAxisAlignment.start:
    case MainAxisAlignment.end:
    case MainAxisAlignment.center:
      return 0.0;
    case MainAxisAlignment.spaceBetween:
      if (childrenLength == 1) return freeSpace;
      return freeSpace / (childrenLength - 1);
    case MainAxisAlignment.spaceAround:
      return freeSpace / childrenLength;
    case MainAxisAlignment.spaceEvenly:
      return freeSpace / (childrenLength + 1);
    default:
      return 0.0;
  }
}

// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
class LayoutProperties {
  LayoutProperties(this.node, {int copyLevel = 1})
      : description = node?.description,
        size = deserializeSize(node?.size),
        constraints = deserializeConstraints(node?.constraints),
        isFlex = node?.isFlex,
        flexFactor = node?.flexFactor,
        children = copyLevel == 0
            ? []
            : node?.childrenNow
                ?.map((child) =>
                    LayoutProperties(child, copyLevel: copyLevel - 1))
                ?.toList(growable: false);

  final RemoteDiagnosticsNode node;
  final List<LayoutProperties> children;
  final BoxConstraints constraints;
  final String description;
  final int flexFactor;
  final bool isFlex;
  final Size size;

  int get totalChildren => children?.length ?? 0;

  bool get hasChildren => children?.isNotEmpty ?? false;

  double get width => size?.width;

  double get height => size?.height;

  double dimension(Axis axis) => axis == Axis.horizontal ? width : height;

  List<double> childrenDimensions(Axis axis) {
    return children?.map((child) => child.dimension(axis))?.toList();
  }

  List<double> get childrenWidths => childrenDimensions(Axis.horizontal);

  List<double> get childrenHeights => childrenDimensions(Axis.vertical);

  String describeWidthConstraints() {
    return constraints.hasBoundedWidth
        ? describeAxis(constraints.minWidth, constraints.maxWidth, 'w')
        : 'w=unconstrained';
  }

  String describeHeightConstraints() {
    return constraints.hasBoundedHeight
        ? describeAxis(constraints.minHeight, constraints.maxHeight, 'h')
        : 'h=unconstrained';
  }

  String describeWidth() => 'w=${toStringAsFixed(size.width)}';

  String describeHeight() => 'h=${toStringAsFixed(size.height)}';

  static String describeAxis(double min, double max, String axis) {
    if (min == max) return '$axis=${min.toStringAsFixed(1)}';
    return '${min.toStringAsFixed(1)}<=$axis<=${max.toStringAsFixed(1)}';
  }

  static BoxConstraints deserializeConstraints(Map<String, Object> json) {
    // TODO(albertusangga): Support SliverConstraint
    if (json == null || json['type'] != boxConstraintsType.toString())
      return null;
    // TODO(albertusangga): Simplify this json (i.e: when maxWidth is null it means it is unbounded)
    return BoxConstraints(
      minWidth: json['minWidth'],
      maxWidth: json['hasBoundedWidth'] ? json['maxWidth'] : double.infinity,
      minHeight: json['minHeight'],
      maxHeight: json['hasBoundedHeight'] ? json['maxHeight'] : double.infinity,
    );
  }

  static Size deserializeSize(Map<String, Object> json) {
    if (json == null) return null;
    return Size(json['width'], json['height']);
  }
}

final Expando<FlexLayoutProperties> _flexLayoutExpando = Expando();

/// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
class FlexLayoutProperties extends LayoutProperties {
  FlexLayoutProperties._(
    RemoteDiagnosticsNode node, {
    this.direction,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment,
    this.textDirection,
    this.verticalDirection,
    this.textBaseline,
  }) : super(node);

  factory FlexLayoutProperties.fromDiagnostics(RemoteDiagnosticsNode node) {
    // Cache the properties on an expando so that local tweaks to
    // FlexLayoutProperties persist across multiple lookups from an
    // RemoteDiagnosticsNode.
    return _flexLayoutExpando[node] ??= _buildNode(node);
  }

  static FlexLayoutProperties _buildNode(RemoteDiagnosticsNode node) {
    final Map<String, Object> renderObjectJson = node.json['renderObject'];
    final List<dynamic> properties = renderObjectJson['properties'];
    final Map<String, Object> data = Map<String, Object>.fromIterable(
      properties,
      key: (property) => property['name'],
      value: (property) => property['description'],
    );
    return FlexLayoutProperties._(
      node,
      direction: _directionUtils.enumEntry(data['direction']),
      mainAxisAlignment:
          _mainAxisAlignmentUtils.enumEntry(data['mainAxisAlignment']),
      mainAxisSize: _mainAxisSizeUtils.enumEntry(data['mainAxisSize']),
      crossAxisAlignment:
          _crossAxisAlignmentUtils.enumEntry(data['crossAxisAlignment']),
      textDirection: _textDirectionUtils.enumEntry(data['textDirection']),
      verticalDirection:
          _verticalDirectionUtils.enumEntry(data['verticalDirection']),
      textBaseline: _textBaselineUtils.enumEntry(data['textBaseline']),
    );
  }

  final Axis direction;
  MainAxisAlignment mainAxisAlignment;
  CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline textBaseline;

  int _totalFlex;

  bool get isMainAxisHorizontal => direction == Axis.horizontal;

  bool get isMainAxisVertical => direction == Axis.vertical;

  String get horizontalDirectionDescription {
    return direction == Axis.horizontal ? 'Main Axis' : 'Cross Axis';
  }

  String get verticalDirectionDescription {
    return direction == Axis.vertical ? 'Main Axis' : 'Cross Axis';
  }

  String get type => direction == Axis.horizontal ? 'Row' : 'Column';

  int get totalFlex {
    if (children?.isEmpty ?? true) return 0;
    _totalFlex ??= children
        .map((child) => child.flexFactor ?? 0)
        .reduce((value, element) => value + element);
    return _totalFlex;
  }

  Axis get crossAxisDirection {
    return direction == Axis.horizontal ? Axis.vertical : Axis.horizontal;
  }

  double get mainAxisDimension => dimension(direction);

  double get crossAxisDimension => dimension(crossAxisDirection);

  List<RenderProps> childrenRenderProps({
    @required double smallestRenderWidth,
    @required double largestRenderWidth,
    @required double smallestRenderHeight,
    @required double largestRenderHeight,
    @required double Function(Axis) maxSizeAvailable,
  }) {
    /// calculate the render empty spaces
    final freeSpace = dimension(direction) - sum(childrenDimensions(direction));

    double smallestRenderSize(Axis axis) {
      return axis == Axis.horizontal
          ? smallestRenderWidth
          : smallestRenderHeight;
    }

    double largestRenderSize(Axis axis) {
      final lrs =
          axis == Axis.horizontal ? largestRenderWidth : largestRenderHeight;
      // use all the space when visualizing cross axis
      return (axis == direction) ? lrs : maxSizeAvailable(axis);
    }

    List<double> renderSizes(Axis axis) {
      final sizes = childrenDimensions(axis);
      if (freeSpace > 0.0 && axis == direction) {
        /// include free space in the computation
        sizes.add(freeSpace);
      }
      final smallestSize = min(sizes);
      final largestSize = max(sizes);
      if (axis == direction ||
          (crossAxisAlignment != CrossAxisAlignment.stretch &&
              smallestSize != largestSize)) {
        return computeRenderSizes(
          sizes: sizes,
          smallestSize: smallestSize,
          largestSize: largestSize,
          smallestRenderSize: smallestRenderSize(axis),
          largestRenderSize: largestRenderSize(axis),
          maxSizeAvailable: maxSizeAvailable(axis),
        );
      } else {
        // uniform cross axis sizes.
        final size = crossAxisAlignment == CrossAxisAlignment.stretch
            ? maxSizeAvailable(axis)
            : largestSize / dimension(axis) * maxSizeAvailable(axis);
        return sizes.map((_) => size).toList();
      }
    }

    final widths = renderSizes(Axis.horizontal);
    final heights = renderSizes(Axis.vertical);

    final renderFreeSpace = freeSpace > 0.0
        ? (isMainAxisHorizontal ? widths.last : heights.last)
        : 0.0;

    double spaceBeforeChildren(double freeSpace) {
      return computeSpaceBeforeChildren(
          mainAxisAlignment: mainAxisAlignment,
          freeSpace: freeSpace,
          childrenLength: children.length);
    }

    double spaceBetweenChildren(double freeSpace) {
      return computeSpaceBetweenChildren(
          mainAxisAlignment: mainAxisAlignment,
          freeSpace: freeSpace,
          childrenLength: children.length);
    }

    double spaceAfterChildren(double freeSpace) {
      return computeSpaceAfterChildren(
          mainAxisAlignment: mainAxisAlignment,
          freeSpace: freeSpace,
          childrenLength: children.length);
    }

    final renderSpaceBeforeChildren = spaceBeforeChildren(renderFreeSpace);
    final renderSpaceBetweenChildren = spaceBetweenChildren(renderFreeSpace);
    final renderSpaceAfterChildren = spaceAfterChildren(renderFreeSpace);

    final childrenRenderProps = <RenderProps>[];

    double lastMainAxisOffset() {
      if (childrenRenderProps.isEmpty) return 0.0;
      return childrenRenderProps.last.mainAxisOffset;
    }

    double lastMainAxisDimension() {
      if (childrenRenderProps.isEmpty) return 0.0;
      return childrenRenderProps.last.mainAxisDimension;
    }

    double space(int index) {
      if (index == 0) return renderSpaceBeforeChildren;
      return renderSpaceBetweenChildren;
    }

    double calculateMainAxisOffset(int i) {
      return lastMainAxisOffset() + lastMainAxisDimension() + space(i);
    }

    double calculateCrossAxisOffset(int i) {
      final maxDimension = maxSizeAvailable(crossAxisDirection);
      final usedDimension =
          crossAxisDirection == Axis.horizontal ? widths[i] : heights[i];

      if (crossAxisAlignment == CrossAxisAlignment.start ||
          crossAxisAlignment == CrossAxisAlignment.stretch ||
          maxDimension == usedDimension) return 0.0;
      final emptySpace = math.max(0.0, maxDimension - usedDimension);
      if (crossAxisAlignment == CrossAxisAlignment.end) return emptySpace;
      return emptySpace * 0.5;
    }

    for (var i = 0; i < children.length; ++i) {
      childrenRenderProps.add(
        RenderProps(
          axis: direction,
          size: Size(widths[i], heights[i]),
          offset: Offset.zero,
          realSize: children[i].size,
        )
          ..mainAxisOffset = calculateMainAxisOffset(i)
          ..crossAxisOffset = calculateCrossAxisOffset(i),
      );
    }

    final spaces = <RenderProps>[];

    final realSpaceBeforeChildren = spaceBeforeChildren(freeSpace);
    final realSpaceBetweenChildren = spaceBetweenChildren(freeSpace);
    final realSpaceAfterChildren = spaceAfterChildren(freeSpace);
    final renderPropsWithFullCrossAxisDimension =
        RenderProps(axis: direction, isFreeSpace: true)
          ..crossAxisDimension = maxSizeAvailable(crossAxisDirection)
          ..crossAxisRealDimension = dimension(crossAxisDirection)
          ..crossAxisOffset = 0.0;
    if (realSpaceBeforeChildren > 0.0) {
      spaces.add(renderPropsWithFullCrossAxisDimension.clone()
        ..mainAxisOffset = 0.0
        ..mainAxisDimension = renderSpaceBeforeChildren
        ..mainAxisRealDimension = realSpaceBeforeChildren);
    }
    if (realSpaceBetweenChildren > 0.0)
      for (var i = 0; i < childrenRenderProps.length - 1; ++i) {
        final child = childrenRenderProps[i];
        spaces.add(renderPropsWithFullCrossAxisDimension.clone()
          ..mainAxisDimension = renderSpaceBetweenChildren
          ..mainAxisRealDimension = realSpaceBetweenChildren
          ..mainAxisOffset = child.mainAxisOffset + child.mainAxisDimension);
      }
    if (realSpaceAfterChildren > 0.0) {
      final lastChildren = childrenRenderProps.last;
      spaces.add(
        renderPropsWithFullCrossAxisDimension.clone()
          ..mainAxisDimension = renderSpaceAfterChildren
          ..mainAxisRealDimension = realSpaceAfterChildren
          ..mainAxisOffset =
              lastChildren.mainAxisOffset + lastChildren.mainAxisDimension,
      );
    }
    return [...childrenRenderProps, ...spaces];
  }

  List<RenderProps> crossAxisSpaces({
    @required List<RenderProps> childrenRenderProps,
    @required double Function(Axis) maxSizeAvailable,
  }) {
    if (crossAxisAlignment == CrossAxisAlignment.stretch) return [];
    final spaces = <RenderProps>[];
    for (var i = 0; i < children.length; ++i) {
      if (dimension(crossAxisDirection) ==
              children[i].dimension(crossAxisDirection) ||
          childrenRenderProps[i].crossAxisDimension ==
              maxSizeAvailable(crossAxisDirection)) continue;

      final renderInfo = childrenRenderProps[i];
      final space = renderInfo.clone();

      space.crossAxisRealDimension =
          crossAxisDimension - space.crossAxisRealDimension;
      space.crossAxisDimension =
          maxSizeAvailable(crossAxisDirection) - space.crossAxisDimension;

      if (crossAxisAlignment == CrossAxisAlignment.center) {
        space.crossAxisDimension *= 0.5;
        space.crossAxisRealDimension *= 0.5;
        spaces.add(space.clone()..crossAxisOffset = 0.0);
        spaces.add(space.clone()
          ..crossAxisOffset =
              renderInfo.crossAxisDimension + renderInfo.crossAxisOffset);
      } else {
        space.crossAxisOffset = crossAxisAlignment == CrossAxisAlignment.end
            ? 0
            : renderInfo.crossAxisDimension;
        spaces.add(space);
      }
    }
    return spaces;
  }

  static final _directionUtils = EnumUtils<Axis>(Axis.values);
  static final _mainAxisAlignmentUtils =
      EnumUtils<MainAxisAlignment>(MainAxisAlignment.values);
  static final _mainAxisSizeUtils =
      EnumUtils<MainAxisSize>(MainAxisSize.values);
  static final _crossAxisAlignmentUtils =
      EnumUtils<CrossAxisAlignment>(CrossAxisAlignment.values);
  static final _textDirectionUtils =
      EnumUtils<TextDirection>(TextDirection.values);
  static final _verticalDirectionUtils =
      EnumUtils<VerticalDirection>(VerticalDirection.values);
  static final _textBaselineUtils =
      EnumUtils<TextBaseline>(TextBaseline.values);
}

class RenderProps {
  RenderProps({
    @required this.axis,
    Size size,
    Offset offset,
    Size realSize,
    this.isFreeSpace = false,
  })  : width = size?.width,
        height = size?.height,
        realWidth = realSize?.width,
        realHeight = realSize?.height,
        dx = offset?.dx,
        dy = offset?.dy;

  final Axis axis;

  bool isFreeSpace;
  double dx, dy;
  double width, height;
  double realWidth, realHeight;

  Size get size => Size(width, height);

  Size get realSize => Size(realWidth, realHeight);

  Offset get offset => Offset(dx, dy);

  double get mainAxisDimension => axis == Axis.horizontal ? width : height;

  set mainAxisDimension(double dim) {
    if (axis == Axis.horizontal)
      width = dim;
    else
      height = dim;
  }

  double get crossAxisDimension => axis == Axis.horizontal ? height : width;

  set crossAxisDimension(double dim) {
    if (axis == Axis.horizontal)
      height = dim;
    else
      width = dim;
  }

  double get mainAxisOffset => axis == Axis.horizontal ? dx : dy;

  set mainAxisOffset(double offset) {
    if (axis == Axis.horizontal)
      dx = offset;
    else
      dy = offset;
  }

  double get crossAxisOffset => axis == Axis.horizontal ? dy : dx;

  set crossAxisOffset(double offset) {
    if (axis == Axis.horizontal)
      dy = offset;
    else
      dx = offset;
  }

  double get mainAxisRealDimension =>
      axis == Axis.horizontal ? realWidth : realHeight;

  set mainAxisRealDimension(double newVal) {
    if (axis == Axis.horizontal)
      realWidth = newVal;
    else
      realHeight = newVal;
  }

  double get crossAxisRealDimension =>
      axis == Axis.horizontal ? realHeight : realWidth;

  set crossAxisRealDimension(double newVal) {
    if (axis == Axis.horizontal)
      realHeight = newVal;
    else
      realWidth = newVal;
  }

  RenderProps clone() {
    return RenderProps(
      axis: axis,
      size: size,
      offset: offset,
      realSize: realSize,
      isFreeSpace: isFreeSpace,
    );
  }
}
