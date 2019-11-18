// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../utils.dart';
import '../diagnostics_node.dart';
import '../enum_utils.dart';

const Type boxConstraintsType = BoxConstraints;

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
                ?.toList(growable: false) {
    if (node != null && children != null && children.isNotEmpty) {
      _smallestHeightChild = children.reduce((value, element) =>
          value.size.height < element.size.height ? value : element);
      _smallestWidthChild = children.reduce((value, element) =>
          value.size.width < element.size.width ? value : element);
      _largestHeightChild = children.reduce((value, element) =>
          value.size.height > element.size.height ? value : element);
      _largestWidthChild = children.reduce((value, element) =>
          value.size.width > element.size.width ? value : element);
    }
  }

  final List<LayoutProperties> children;
  final BoxConstraints constraints;
  final String description;
  final int flexFactor;
  final bool isFlex;
  final Size size;

  LayoutProperties _smallestHeightChild;
  LayoutProperties _smallestWidthChild;
  LayoutProperties _largestHeightChild;
  LayoutProperties _largestWidthChild;

  int get totalChildren => children?.length ?? 0;

  bool get hasChildren => children?.isNotEmpty ?? false;

  LayoutProperties get smallestWidthChild => _smallestWidthChild;

  LayoutProperties get smallestHeightChild => _smallestHeightChild;

  LayoutProperties get largestWidthChild => _largestWidthChild;

  LayoutProperties get largestHeightChild => _largestHeightChild;

  double get smallestWidthChildFraction => _smallestWidthChild.width / width;

  double get smallestHeightChildFraction =>
      _smallestHeightChild.height / height;

  double get largestWidthChildFraction => _largestWidthChild.width / width;

  double get largestHeightChildFraction => _largestHeightChild.height / height;

  double get width => size?.width;

  double get height => size?.height;

  Iterable<double> get childrenWidth => children?.map((child) => child.width);

  Iterable<double> get childrenHeight => children?.map((child) => child.height);

  String describeWidthConstraints() => constraints.hasBoundedWidth
      ? describeAxis(constraints.minWidth, constraints.maxWidth, 'w')
      : 'w=unconstrained';

  String describeHeightConstraints() => constraints.hasBoundedHeight
      ? describeAxis(constraints.minHeight, constraints.maxHeight, 'h')
      : 'h=unconstrained';

  String describeWidth() {
    return 'w=${toStringAsFixed(size.width)}';
  }

  String describeHeight() {
    return 'h=${toStringAsFixed(size.height)}';
  }

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

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline textBaseline;

  int _totalFlex;

  static FlexLayoutProperties fromRemoteDiagnosticsNode(
      RemoteDiagnosticsNode node) {
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

  bool get isHorizontalMainAxis => direction == Axis.horizontal;

  bool get isVerticalMainAxis => direction == Axis.vertical;

  String get horizontalDirectionDescription =>
      direction == Axis.horizontal ? 'Main Axis' : 'Cross Axis';

  String get verticalDirectionDescription =>
      direction == Axis.vertical ? 'Main Axis' : 'Cross Axis';

  // TODO(albertusangga): Remove this getter since type is not that useful
  Type get type => direction == Axis.horizontal ? Row : Column;

  int get totalFlex {
    if (children?.isEmpty ?? true) return 0;
    _totalFlex ??= children
        .map((child) => child.flexFactor ?? 0)
        .reduce((value, element) => value + element);
    return _totalFlex;
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
