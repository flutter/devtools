// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../enum_utils.dart';
import '../../utils.dart';
import '../diagnostics_node.dart';
import 'layout_explorer/flex/utils.dart';

const overflowEpsilon = 0.1;

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

// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
/// Represents parsed layout information for a specific [RemoteDiagnosticsNode].
class LayoutProperties {
  LayoutProperties(this.node, {int copyLevel = 1})
      : description = node?.description,
        size = deserializeSize(node?.size),
        constraints = deserializeConstraints(node?.constraints),
        isFlex = node?.isFlex,
        flexFactor = node?.flexFactor,
        flexFit = deserializeFlexFit(node?.flexFit),
        children = copyLevel == 0
            ? []
            : node?.childrenNow
                ?.map((child) =>
                    LayoutProperties(child, copyLevel: copyLevel - 1))
                ?.toList(growable: false) {
    if (children?.isNotEmpty ?? false)
      for (var child in children) {
        child.parent = this;
      }
  }

  LayoutProperties.values({
    @required this.node,
    @required this.children,
    @required this.constraints,
    @required this.description,
    @required this.flexFactor,
    @required this.isFlex,
    @required this.size,
    @required this.flexFit,
  }) {
    for (var child in children) {
      child.parent = this;
    }
  }

  factory LayoutProperties.lerp(
    LayoutProperties begin,
    LayoutProperties end,
    double t,
  ) {
    return LayoutProperties.values(
      node: end.node,
      children: end.children,
      constraints: BoxConstraints.lerp(begin.constraints, end.constraints, t),
      description: end.description,
      flexFactor: begin.flexFactor + (begin.flexFactor - end.flexFactor) * t,
      isFlex: begin.isFlex && end.isFlex,
      size: Size.lerp(begin.size, end.size, t),
      flexFit: end.flexFit,
    );
  }

  LayoutProperties parent;
  final RemoteDiagnosticsNode node;
  final List<LayoutProperties> children;
  final BoxConstraints constraints;
  final String description;
  final num flexFactor;
  final FlexFit flexFit;
  final bool isFlex;
  final Size size;

  bool get hasFlexFactor => flexFactor != null && flexFactor > 0;

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

  bool get isOverflowWidth {
    return width > parent.width + overflowEpsilon;
  }

  bool get isOverflowHeight {
    return height > parent.height + overflowEpsilon;
  }

  static String describeAxis(double min, double max, String axis) {
    if (min == max) return '$axis=${min.toStringAsFixed(1)}';
    return '${min.toStringAsFixed(1)}<=$axis<=${max.toStringAsFixed(1)}';
  }

  static BoxConstraints deserializeConstraints(Map<String, Object> json) {
    // TODO(albertusangga): Support SliverConstraint
    if (json == null) return null;
    return BoxConstraints(
      minWidth: double.parse(json['minWidth'] ?? '0.0'),
      maxWidth: double.parse(json['maxWidth'] ?? 'Infinity'),
      minHeight: double.parse(json['minHeight'] ?? '0.0'),
      maxHeight: double.parse(json['maxHeight'] ?? 'Infinity'),
    );
  }

  static Size deserializeSize(Map<String, Object> json) {
    if (json == null) return null;
    return Size(
      double.parse(json['width']),
      double.parse(json['height']),
    );
  }

  LayoutProperties copyWith({
    List<LayoutProperties> children,
    BoxConstraints constraints,
    String description,
    int flexFactor,
    FlexFit flexFit,
    bool isFlex,
    Size size,
  }) {
    return LayoutProperties.values(
      node: node,
      children: children ?? this.children,
      constraints: constraints ?? this.constraints,
      description: description ?? this.description,
      flexFactor: flexFactor ?? this.flexFactor,
      isFlex: isFlex ?? this.isFlex,
      size: size ?? this.size,
      flexFit: flexFit ?? this.flexFit,
    );
  }

  static FlexFit deserializeFlexFit(String flexFit) {
    if (flexFit == null)
      return null;
    else if (flexFit == 'tight') return FlexFit.tight;
    return FlexFit.loose;
  }
}

final Expando<FlexLayoutProperties> _flexLayoutExpando = Expando();

/// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
class FlexLayoutProperties extends LayoutProperties {
  FlexLayoutProperties({
    Size size,
    List<LayoutProperties> children,
    RemoteDiagnosticsNode node,
    BoxConstraints constraints,
    bool isFlex,
    String description,
    num flexFactor,
    FlexFit flexFit,
    this.direction,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.mainAxisSize,
    this.textDirection,
    this.verticalDirection,
    this.textBaseline,
  }) : super.values(
          size: size,
          children: children,
          node: node,
          constraints: constraints,
          isFlex: isFlex,
          description: description,
          flexFactor: flexFactor,
          flexFit: flexFit,
        );

  FlexLayoutProperties._fromNode(
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
    if (node == null) return null;
    // Cache the properties on an expando so that local tweaks to
    // FlexLayoutProperties persist across multiple lookups from an
    // RemoteDiagnosticsNode.
    return _flexLayoutExpando[node] ??= _buildNode(node);
  }

  @override
  FlexLayoutProperties copyWith({
    Size size,
    List<LayoutProperties> children,
    BoxConstraints constraints,
    bool isFlex,
    String description,
    num flexFactor,
    FlexFit flexFit,
    Axis direction,
    MainAxisAlignment mainAxisAlignment,
    MainAxisSize mainAxisSize,
    CrossAxisAlignment crossAxisAlignment,
    TextDirection textDirection,
    VerticalDirection verticalDirection,
    TextBaseline textBaseline,
  }) {
    return FlexLayoutProperties(
      size: size ?? this.size,
      children: children ?? this.children,
      node: node,
      constraints: constraints ?? this.constraints,
      isFlex: isFlex ?? this.isFlex,
      description: description ?? this.description,
      flexFactor: flexFactor ?? this.flexFactor,
      flexFit: flexFit ?? this.flexFit,
      direction: direction ?? this.direction,
      mainAxisAlignment: mainAxisAlignment ?? this.mainAxisAlignment,
      mainAxisSize: mainAxisSize ?? this.mainAxisSize,
      crossAxisAlignment: crossAxisAlignment ?? this.crossAxisAlignment,
      textDirection: textDirection ?? this.textDirection,
      verticalDirection: verticalDirection ?? this.verticalDirection,
      textBaseline: textBaseline ?? this.textBaseline,
    );
  }

  static FlexLayoutProperties _buildNode(RemoteDiagnosticsNode node) {
    final Map<String, Object> renderObjectJson = node?.renderObject;
    if (renderObjectJson == null) return null;
    final List<dynamic> properties = renderObjectJson['properties'];
    final Map<String, Object> data = Map<String, Object>.fromIterable(
      properties,
      key: (property) => property['name'],
      value: (property) => property['description'],
    );
    return FlexLayoutProperties._fromNode(
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
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
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

  String get type => direction.flexType;

  num get totalFlex {
    if (children?.isEmpty ?? true) return 0;
    _totalFlex ??= children
        .map((child) => child.flexFactor ?? 0)
        .reduce((value, element) => value + element)
        .toInt();
    return _totalFlex;
  }

  Axis get crossAxisDirection {
    return direction == Axis.horizontal ? Axis.vertical : Axis.horizontal;
  }

  double get mainAxisDimension => dimension(direction);

  double get crossAxisDimension => dimension(crossAxisDirection);

  @override
  bool get isOverflowWidth {
    if (direction == Axis.horizontal)
      return width + overflowEpsilon < sum(childrenWidths);
    return width + overflowEpsilon < max(childrenWidths);
  }

  @override
  bool get isOverflowHeight {
    if (direction == Axis.vertical)
      return height + overflowEpsilon < sum(childrenHeights);
    return height + overflowEpsilon < max(childrenHeights);
  }

  /// render properties for laying out rendered Flex & Flex children widgets
  /// the computation is similar to [RenderFlex].performLayout() method
  List<RenderProperties> childrenRenderProperties({
    @required double smallestRenderWidth,
    @required double largestRenderWidth,
    @required double smallestRenderHeight,
    @required double largestRenderHeight,
    @required double Function(Axis) maxSizeAvailable,
  }) {
    /// calculate the render empty spaces
    final freeSpace = dimension(direction) - sum(childrenDimensions(direction));

    double leadingSpace(double freeSpace) {
      if (children.isEmpty) return 0.0;
      switch (mainAxisAlignment) {
        case MainAxisAlignment.start:
        case MainAxisAlignment.end:
          return freeSpace;
        case MainAxisAlignment.center:
          return freeSpace * 0.5;
        case MainAxisAlignment.spaceBetween:
          return 0.0;
        case MainAxisAlignment.spaceAround:
          final spaceBetweenChildren = freeSpace / children.length;
          return spaceBetweenChildren * 0.5;
        case MainAxisAlignment.spaceEvenly:
          return freeSpace / (children.length + 1);
        default:
          return 0.0;
      }
    }

    double betweenSpace(double freeSpace) {
      if (children.isEmpty) return 0.0;
      switch (mainAxisAlignment) {
        case MainAxisAlignment.start:
        case MainAxisAlignment.end:
        case MainAxisAlignment.center:
          return 0.0;
        case MainAxisAlignment.spaceBetween:
          if (children.length == 1) return freeSpace;
          return freeSpace / (children.length - 1);
        case MainAxisAlignment.spaceAround:
          return freeSpace / children.length;
        case MainAxisAlignment.spaceEvenly:
          return freeSpace / (children.length + 1);
        default:
          return 0.0;
      }
    }

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
        double size = crossAxisAlignment == CrossAxisAlignment.stretch
            ? maxSizeAvailable(axis)
            : largestSize /
                math.max(dimension(axis), 1.0) *
                maxSizeAvailable(axis);
        size = math.max(size, smallestRenderSize(axis));
        return sizes.map((_) => size).toList();
      }
    }

    final widths = renderSizes(Axis.horizontal);
    final heights = renderSizes(Axis.vertical);

    final renderFreeSpace = freeSpace > 0.0
        ? (isMainAxisHorizontal ? widths.last : heights.last)
        : 0.0;

    final renderLeadingSpace = leadingSpace(renderFreeSpace);
    final renderBetweenSpace = betweenSpace(renderFreeSpace);

    final childrenRenderProps = <RenderProperties>[];

    double lastMainAxisOffset() {
      if (childrenRenderProps.isEmpty) return 0.0;
      return childrenRenderProps.last.mainAxisOffset;
    }

    double lastMainAxisDimension() {
      if (childrenRenderProps.isEmpty) return 0.0;
      return childrenRenderProps.last.mainAxisDimension;
    }

    double space(int index) {
      if (index == 0) {
        if (mainAxisAlignment == MainAxisAlignment.start) return 0.0;
        return renderLeadingSpace;
      }
      return renderBetweenSpace;
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
        RenderProperties(
          axis: direction,
          size: Size(widths[i], heights[i]),
          offset: Offset.zero,
          realSize: children[i].size,
        )
          ..mainAxisOffset = calculateMainAxisOffset(i)
          ..crossAxisOffset = calculateCrossAxisOffset(i)
          ..layoutProperties = children[i],
      );
    }

    final spaces = <RenderProperties>[];
    final actualLeadingSpace = leadingSpace(freeSpace);
    final actualBetweenSpace = betweenSpace(freeSpace);
    final renderPropsWithFullCrossAxisDimension =
        RenderProperties(axis: direction)
          ..crossAxisDimension = maxSizeAvailable(crossAxisDirection)
          ..crossAxisRealDimension = dimension(crossAxisDirection)
          ..crossAxisOffset = 0.0
          ..isFreeSpace = true
          ..layoutProperties = this;
    if (actualLeadingSpace > 0.0 &&
        mainAxisAlignment != MainAxisAlignment.start) {
      spaces.add(renderPropsWithFullCrossAxisDimension.clone()
        ..mainAxisOffset = 0.0
        ..mainAxisDimension = renderLeadingSpace
        ..mainAxisRealDimension = actualLeadingSpace);
    }
    if (actualBetweenSpace > 0.0)
      for (var i = 0; i < childrenRenderProps.length - 1; ++i) {
        final child = childrenRenderProps[i];
        spaces.add(renderPropsWithFullCrossAxisDimension.clone()
          ..mainAxisDimension = renderBetweenSpace
          ..mainAxisRealDimension = actualBetweenSpace
          ..mainAxisOffset = child.mainAxisOffset + child.mainAxisDimension);
      }
    if (actualLeadingSpace > 0.0 &&
        mainAxisAlignment != MainAxisAlignment.end) {
      spaces.add(renderPropsWithFullCrossAxisDimension.clone()
        ..mainAxisOffset = childrenRenderProps.last.mainAxisDimension +
            childrenRenderProps.last.mainAxisOffset
        ..mainAxisDimension = renderLeadingSpace
        ..mainAxisRealDimension = actualLeadingSpace);
    }
    return [...childrenRenderProps, ...spaces];
  }

  List<RenderProperties> crossAxisSpaces({
    @required List<RenderProperties> childrenRenderProperties,
    @required double Function(Axis) maxSizeAvailable,
  }) {
    if (crossAxisAlignment == CrossAxisAlignment.stretch) return [];
    final spaces = <RenderProperties>[];
    for (var i = 0; i < children.length; ++i) {
      if (dimension(crossAxisDirection) ==
              children[i].dimension(crossAxisDirection) ||
          childrenRenderProperties[i].crossAxisDimension ==
              maxSizeAvailable(crossAxisDirection)) continue;

      final renderProperties = childrenRenderProperties[i];
      final space = renderProperties.clone()..isFreeSpace = true;

      space.crossAxisRealDimension =
          crossAxisDimension - space.crossAxisRealDimension;
      space.crossAxisDimension =
          maxSizeAvailable(crossAxisDirection) - space.crossAxisDimension;
      if (space.crossAxisDimension <= 0.0) continue;
      if (crossAxisAlignment == CrossAxisAlignment.center) {
        space.crossAxisDimension *= 0.5;
        space.crossAxisRealDimension *= 0.5;
        spaces.add(space.clone()..crossAxisOffset = 0.0);
        spaces.add(space.clone()
          ..crossAxisOffset = renderProperties.crossAxisDimension +
              renderProperties.crossAxisOffset);
      } else {
        space.crossAxisOffset = crossAxisAlignment == CrossAxisAlignment.end
            ? 0
            : renderProperties.crossAxisDimension;
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

/// RenderProperties contains information for rendering a [LayoutProperties] node
class RenderProperties {
  RenderProperties({
    @required this.axis,
    Size size,
    Offset offset,
    Size realSize,
    this.layoutProperties,
    this.isFreeSpace = false,
  })  : width = size?.width ?? 0.0,
        height = size?.height ?? 0.0,
        realWidth = realSize?.width ?? 0.0,
        realHeight = realSize?.height ?? 0.0,
        dx = offset?.dx ?? 0.0,
        dy = offset?.dy ?? 0.0;

  final Axis axis;

  /// represents which node is rendered for this object.
  LayoutProperties layoutProperties;

  double dx, dy;
  double width, height;
  double realWidth, realHeight;

  bool isFreeSpace;

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

  RenderProperties clone() {
    return RenderProperties(
      axis: axis,
      size: size,
      offset: offset,
      realSize: realSize,
      layoutProperties: layoutProperties,
      isFreeSpace: isFreeSpace,
    );
  }
}
