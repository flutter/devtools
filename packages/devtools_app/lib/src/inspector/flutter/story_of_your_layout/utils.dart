// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui';

import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../utils.dart';
import '../inspector_data_models.dart';

double sum(Iterable<double> numbers) =>
    numbers.fold(0, (sum, cur) => sum + cur);

double min(Iterable<double> numbers) =>
    numbers.fold(double.infinity, (minimum, cur) => math.min(minimum, cur));

double max(Iterable<double> numbers) =>
    numbers.fold(-double.infinity, (minimum, cur) => math.max(minimum, cur));

String crossAxisAssetImageUrl(CrossAxisAlignment alignment) {
  return 'assets/img/story_of_layout/cross_axis_alignment/${describeEnum(alignment)}.png';
}

String mainAxisAssetImageUrl(MainAxisAlignment alignment) {
  return 'assets/img/story_of_layout/main_axis_alignment/${describeEnum(alignment)}.png';
}

/// A widget for positioning sized widgets that follows layout as follows:
///      | top    |
/// left | center | right
///      | bottom |
@immutable
class BorderLayout extends StatelessWidget {
  const BorderLayout({
    Key key,
    this.left,
    this.leftWidth,
    this.top,
    this.topHeight,
    this.right,
    this.rightWidth,
    this.bottom,
    this.bottomHeight,
    this.center,
  })  : assert(left != null ||
            top != null ||
            right != null ||
            bottom != null ||
            center != null),
        super(key: key);

  final Widget center;
  final Widget top;
  final Widget left;
  final Widget right;
  final Widget bottom;

  final double leftWidth;
  final double rightWidth;
  final double topHeight;
  final double bottomHeight;

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
    return Stack(
      children: <Widget>[
        Center(
          child: Container(
            margin: EdgeInsets.only(
              left: leftWidth ?? 0,
              right: rightWidth ?? 0,
              top: topHeight ?? 0,
              bottom: bottomHeight ?? 0,
            ),
            child: center,
          ),
        ),
        if (top != null)
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: topHeight, child: top),
          ),
        if (left != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(width: leftWidth, child: left),
          ),
        if (right != null)
          Align(
            alignment: Alignment.centerRight,
            child: Container(width: rightWidth, child: right),
          ),
        if (bottom != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: bottomHeight, child: bottom),
          )
      ],
    );
  }
}

class AnimatedLayoutProperties<T extends LayoutProperties>
    implements LayoutProperties {
  AnimatedLayoutProperties(this.begin, this.end, this.animation)
      : assert(begin.children.length == end.children.length),
        _children = [
          for (var i = 0; i < begin.children.length; i++)
            AnimatedLayoutProperties(
              begin.children[i],
              end.children[i],
              animation,
            )
        ];

  final T begin;
  final T end;
  final Animation<double> animation;
  final List<LayoutProperties> _children;

  @override
  List<LayoutProperties> get children => _children;

  List<double> _lerpList(List<double> l1, List<double> l2) {
    assert(l1.length == l2.length);
    return [
      for (var i = 0; i < children.length; i++)
        lerpDouble(l1[i], l2[i], animation.value)
    ];
  }

  @override
  List<double> childrenDimensions(Axis axis) {
    final beginDimensions = begin.childrenDimensions(axis);
    final endDimensions = end.childrenDimensions(axis);
    return _lerpList(beginDimensions, endDimensions);
  }

  @override
  List<double> get childrenHeights =>
      _lerpList(begin.childrenHeights, end.childrenHeights);

  @override
  List<double> get childrenWidths =>
      _lerpList(begin.childrenWidths, end.childrenWidths);

  @override
  BoxConstraints get constraints =>
      BoxConstraints.lerp(begin.constraints, end.constraints, animation.value);

  @override
  String describeWidthConstraints() {
    return constraints.hasBoundedWidth
        ? LayoutProperties.describeAxis(
            constraints.minWidth, constraints.maxWidth, 'w')
        : 'w=unconstrained';
  }

  @override
  String describeHeightConstraints() {
    return constraints.hasBoundedHeight
        ? LayoutProperties.describeAxis(
            constraints.minHeight, constraints.maxHeight, 'h')
        : 'h=unconstrained';
  }

  @override
  String describeWidth() => 'w=${toStringAsFixed(size.width)}';

  @override
  String describeHeight() => 'h=${toStringAsFixed(size.height)}';

  @override
  String get description => end.description;

  @override
  double dimension(Axis axis) {
    return lerpDouble(
      begin.dimension(axis),
      end.dimension(axis),
      animation.value,
    );
  }

  @override
  num get flexFactor =>
      lerpDouble(begin.flexFactor, end.flexFactor, animation.value);

  @override
  bool get hasChildren => children.isNotEmpty;

  @override
  double get height => size.height;

  @override
  bool get isFlex => begin.isFlex && end.isFlex;

  @override
  RemoteDiagnosticsNode get node => end.node;

  @override
  Size get size => Size.lerp(begin.size, end.size, animation.value);

  @override
  int get totalChildren => end.totalChildren;

  @override
  double get width => size.width;

  @override
  bool get hasFlexFactor => begin.hasFlexFactor && end.hasFlexFactor;
}

class AnimatedFlexLayoutProperties
    extends AnimatedLayoutProperties<FlexLayoutProperties>
    implements FlexLayoutProperties {
  AnimatedFlexLayoutProperties(FlexLayoutProperties begin,
      FlexLayoutProperties end, Animation<double> animation)
      : super(begin, end, animation);

  @override
  CrossAxisAlignment get crossAxisAlignment => end.crossAxisAlignment;

  @override
  MainAxisAlignment get mainAxisAlignment => end.mainAxisAlignment;

  @override
  List<RenderProperties> childrenRenderProperties(
      {double smallestRenderWidth,
      double largestRenderWidth,
      double smallestRenderHeight,
      double largestRenderHeight,
      double Function(Axis) maxSizeAvailable}) {
    final beginRenderProperties = begin.childrenRenderProperties(
      smallestRenderHeight: smallestRenderHeight,
      smallestRenderWidth: smallestRenderWidth,
      largestRenderHeight: largestRenderHeight,
      largestRenderWidth: largestRenderWidth,
      maxSizeAvailable: maxSizeAvailable,
    );
    final endRenderProperties = end.childrenRenderProperties(
      smallestRenderHeight: smallestRenderHeight,
      smallestRenderWidth: smallestRenderWidth,
      largestRenderHeight: largestRenderHeight,
      largestRenderWidth: largestRenderWidth,
      maxSizeAvailable: maxSizeAvailable,
    );
    final result = <RenderProperties>[];
    for (var i = 0; i < children.length; i++) {
      final beginProps = beginRenderProperties[i];
      final endProps = endRenderProperties[i];
      final t = animation.value;
      result.add(
        RenderProperties(
          axis: endProps.axis,
          offset: Offset.lerp(beginProps.offset, endProps.offset, t),
          size: Size.lerp(beginProps.size, endProps.size, t),
          realSize: Size.lerp(beginProps.realSize, endProps.realSize, t),
          layoutProperties: AnimatedLayoutProperties(
            beginProps.layoutProperties,
            endProps.layoutProperties,
            animation,
          ),
        ),
      );
    }
    // Add in the free space from the end.
    // TODO(djshuckerow): We should make free space a part of
    // RenderProperties so that we can animate between those.
    result.addAll(endRenderProperties.where((prop) => prop.isFreeSpace));
    return result;
  }

  @override
  double get crossAxisDimension => lerpDouble(
        begin.crossAxisDimension,
        end.crossAxisDimension,
        animation.value,
      );

  @override
  Axis get crossAxisDirection => end.crossAxisDirection;

  @override
  List<RenderProperties> crossAxisSpaces(
      {List<RenderProperties> childrenRenderProperties,
      double Function(Axis) maxSizeAvailable}) {
    return end.crossAxisSpaces(
      childrenRenderProperties: childrenRenderProperties,
      maxSizeAvailable: maxSizeAvailable,
    );
  }

  @override
  Axis get direction => end.direction;

  @override
  String get horizontalDirectionDescription =>
      end.horizontalDirectionDescription;

  @override
  bool get isMainAxisHorizontal => end.isMainAxisHorizontal;

  @override
  bool get isMainAxisVertical => end.isMainAxisVertical;

  @override
  double get mainAxisDimension => lerpDouble(
        begin.mainAxisDimension,
        end.mainAxisDimension,
        animation.value,
      );

  @override
  MainAxisSize get mainAxisSize => end.mainAxisSize;

  @override
  TextBaseline get textBaseline => end.textBaseline;

  @override
  TextDirection get textDirection => end.textDirection;

  @override
  num get totalFlex =>
      lerpDouble(begin.totalFlex, end.totalFlex, animation.value);

  @override
  String get type => end.type;

  @override
  VerticalDirection get verticalDirection => end.verticalDirection;

  @override
  String get verticalDirectionDescription => end.verticalDirectionDescription;

  /// Returns a frozen copy of these FlexLayoutProperties that does not animate.
  ///
  /// Useful for interrupting an animation with a transition to another [FlexLayoutProperties].
  @override
  FlexLayoutProperties copyWith(
      {Size size,
      List<LayoutProperties> children,
      BoxConstraints constraints,
      bool isFlex,
      String description,
      num flexFactor,
      Axis direction,
      MainAxisAlignment mainAxisAlignment,
      MainAxisSize mainAxisSize,
      CrossAxisAlignment crossAxisAlignment,
      TextDirection textDirection,
      VerticalDirection verticalDirection,
      TextBaseline textBaseline}) {
    return FlexLayoutProperties(
      size: size ?? this.size,
      children: children ?? this.children,
      node: node,
      constraints: constraints ?? this.constraints,
      isFlex: isFlex ?? this.isFlex,
      description: description ?? this.description,
      flexFactor: flexFactor ?? this.flexFactor,
      direction: direction ?? this.direction,
      mainAxisAlignment: mainAxisAlignment ?? this.mainAxisAlignment,
      mainAxisSize: mainAxisSize ?? this.mainAxisSize,
      crossAxisAlignment: crossAxisAlignment ?? this.crossAxisAlignment,
      textDirection: textDirection ?? this.textDirection,
      verticalDirection: verticalDirection ?? this.verticalDirection,
      textBaseline: textBaseline ?? this.textBaseline,
    );
  }
}
