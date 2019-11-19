// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' show max;

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
/// - ss: [smallestSize], the smallest element in the array [sizes]
/// - ls: [largestSize], the largest element in the array [sizes]
/// - srs: [smallestRenderSize] (render size for smallest element)
/// - lrs: [largestRenderSize] (render size for largest element)
/// Explanation:
/// - The computation formula for transforming size to renderSize is based on these two things:
///   - smallest element will be rendered to [smallestRenderSize]
///   - largest element will be rendered to [largestRenderSize]
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
  bool forceToOccupyMaxSizeAvailable = true,
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

// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
class LayoutProperties {
  LayoutProperties(RemoteDiagnosticsNode node, {int copyLevel = 1})
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

  List<Size> childrenRenderSizes({
    @required double smallestRenderWidth,
    @required double largestRenderWidth,
    @required double smallestRenderHeight,
    @required double largestRenderHeight,
    @required double maxWidthAvailable,
    @required double maxHeightAvailable,
  }) {
    double maxSizeAvailable(Axis axis) {
      return axis == Axis.horizontal ? maxWidthAvailable : maxHeightAvailable;
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
      final smallestSize = minimum(sizes);
      final largestSize = maximum(sizes);
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
        final size = largestSize / dimension(axis) * maxSizeAvailable(axis);
        return sizes.map((_) => size).toList();
      }
    }

    final widths = renderSizes(Axis.horizontal);
    final heights = renderSizes(Axis.vertical);
    assert(widths.length == heights.length);
    return [
      for (var i = 0; i < widths.length; ++i) Size(widths[i], heights[i])
    ];
  }

  double _calculateCrossAxisOffset(double maxDimension, double usedDimension) {
    if (crossAxisAlignment == CrossAxisAlignment.start ||
        crossAxisAlignment == CrossAxisAlignment.stretch ||
        maxDimension == usedDimension) return 0.0;
    final emptySpace = max(0.0, maxDimension - usedDimension);
    if (crossAxisAlignment == CrossAxisAlignment.end) return emptySpace;
    return emptySpace * 0.5;
  }

  List<Offset> childrenRenderOffsets({
    @required List<Size> childrenRenderSizes,
    @required double maxWidthAvailable,
    @required double maxHeightAvailable,
  }) {
    final offsets = <Offset>[];
    for (var i = 0; i < children.length; ++i) {
      double dx, dy;
      if (direction == Axis.horizontal) {
        dx = i == 0 ? 0.0 : offsets.last.dx + childrenRenderSizes[i - 1].width;
        dy = _calculateCrossAxisOffset(
            maxHeightAvailable, childrenRenderSizes[i].height);
      } else {
        dy = i == 0 ? 0.0 : offsets.last.dy + childrenRenderSizes[i - 1].height;
        dx = _calculateCrossAxisOffset(
            maxWidthAvailable, childrenRenderSizes[i].width);
      }
      offsets.add(Offset(dx, dy));
    }
    return offsets;
  }

  List<RenderInfo> childrenRenderInformation({
    @required double smallestRenderWidth,
    @required double largestRenderWidth,
    @required double smallestRenderHeight,
    @required double largestRenderHeight,
    @required double maxWidthAvailable,
    @required double maxHeightAvailable,
  }) {
    final renderSizes = childrenRenderSizes(
      smallestRenderWidth: smallestRenderWidth,
      largestRenderWidth: largestRenderWidth,
      smallestRenderHeight: smallestRenderHeight,
      largestRenderHeight: largestRenderHeight,
      maxWidthAvailable: maxWidthAvailable,
      maxHeightAvailable: maxHeightAvailable,
    );
    final renderOffsets = childrenRenderOffsets(
      childrenRenderSizes: renderSizes,
      maxWidthAvailable: maxWidthAvailable,
      maxHeightAvailable: maxHeightAvailable,
    );
    return [
      for (var i = 0; i < children.length; ++i)
        RenderInfo(
            direction, renderSizes[i], renderOffsets[i], children[i].size)
    ];
  }

  List<RenderInfo> crossAxisSpaces({
    List<RenderInfo> childrenRenderInfo,
    double maxWidthAvailable,
    double maxHeightAvailable,
  }) {
    if (crossAxisAlignment == CrossAxisAlignment.stretch) return [];
    final spaces = <RenderInfo>[];
    final maxSizeAvailable = crossAxisDirection == Axis.horizontal
        ? maxWidthAvailable
        : maxHeightAvailable;
    for (var i = 0; i < children.length; ++i) {
      if (dimension(crossAxisDirection) ==
              children[i].dimension(crossAxisDirection) ||
          childrenRenderInfo[i].crossAxisDimension == maxSizeAvailable)
        continue;

      final renderInfo = childrenRenderInfo[i];
      final space = renderInfo.copy();

      space.crossAxisRealDimension =
          crossAxisDimension - space.crossAxisRealDimension;
      space.crossAxisDimension = maxSizeAvailable - space.crossAxisDimension;

      if (crossAxisAlignment == CrossAxisAlignment.center) {
        space.crossAxisDimension *= 0.5;
        space.crossAxisRealDimension *= 0.5;
        spaces.add(space.copy()..crossAxisOffset = 0.0);
        spaces.add(space.copy()
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

class RenderInfo {
  RenderInfo(this.axis, Size size, Offset offset, Size realSize)
      : width = size.width,
        height = size.height,
        realWidth = realSize.width,
        realHeight = realSize.height,
        dx = offset.dx,
        dy = offset.dy;

  final Axis axis;

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

  RenderInfo copy() {
    return RenderInfo(axis, size, offset, realSize);
  }
}
