// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../inspector_data_models.dart';
import '../ui/utils.dart';

String crossAxisAssetImageUrl(Axis direction, CrossAxisAlignment alignment) {
  return 'assets/img/layout_explorer/cross_axis_alignment/'
      '${direction.flexType.toLowerCase()}_${alignment.name}.png';
}

String mainAxisAssetImageUrl(Axis direction, MainAxisAlignment alignment) {
  return 'assets/img/layout_explorer/main_axis_alignment/'
      '${direction.flexType.toLowerCase()}_${alignment.name}.png';
}

class AnimatedFlexLayoutProperties
    extends AnimatedLayoutProperties<FlexLayoutProperties>
    implements FlexLayoutProperties {
  AnimatedFlexLayoutProperties(
    super.begin,
    super.end,
    super.animation,
  );

  @override
  CrossAxisAlignment? get crossAxisAlignment => end.crossAxisAlignment;

  @override
  MainAxisAlignment? get mainAxisAlignment => end.mainAxisAlignment;

  @override
  List<RenderProperties> childrenRenderProperties({
    required double smallestRenderWidth,
    required double largestRenderWidth,
    required double smallestRenderHeight,
    required double largestRenderHeight,
    required double Function(Axis) maxSizeAvailable,
  }) {
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
          // TODO(polina-c, jacob314): crnsider refactoring to get rid of `!`.
          layoutProperties: AnimatedLayoutProperties(
            beginProps.layoutProperties!,
            endProps.layoutProperties!,
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
      )!;

  @override
  Axis get crossAxisDirection => end.crossAxisDirection;

  @override
  List<RenderProperties> crossAxisSpaces({
    required List<RenderProperties> childrenRenderProperties,
    required double Function(Axis) maxSizeAvailable,
  }) {
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
      )!;

  @override
  MainAxisSize? get mainAxisSize => end.mainAxisSize;

  @override
  TextBaseline? get textBaseline => end.textBaseline;

  @override
  TextDirection get textDirection => end.textDirection;

  @override
  double get totalFlex =>
      lerpDouble(begin.totalFlex, end.totalFlex, animation.value)!;

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
  FlexLayoutProperties copyWith({
    Size? size,
    List<LayoutProperties>? children,
    BoxConstraints? constraints,
    bool? isFlex,
    String? description,
    num? flexFactor,
    FlexFit? flexFit,
    Axis? direction,
    MainAxisAlignment? mainAxisAlignment,
    MainAxisSize? mainAxisSize,
    CrossAxisAlignment? crossAxisAlignment,
    TextDirection? textDirection,
    VerticalDirection? verticalDirection,
    TextBaseline? textBaseline,
  }) {
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

  @override
  bool get startIsTopLeft => end.startIsTopLeft;
}

/// LayoutProperties extension to be reused on LayoutProperties and AnimatedLayoutProperties

extension AxisExtension on Axis {
  String get flexType {
    switch (this) {
      case Axis.horizontal:
        return 'Row';
      case Axis.vertical:
      default:
        return 'Column';
    }
  }
}
