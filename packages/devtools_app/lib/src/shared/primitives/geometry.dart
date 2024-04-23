// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

// TODO(kenz): consolidate the logic between [VerticalLineSegment] and
// [HorizontalLineSegment] by using [LineSegment] and switching on the main axis
abstract class LineSegment {
  LineSegment(this.start, this.end, {required this.opacity});

  final Offset start;
  final Offset end;
  final double opacity;

  /// Whether [this] line segment intersects [rect] along the cross axis.
  ///
  /// For [HorizontalLineSegment]s, this will return true if [this] line segment
  /// fits within the y bounds of the [rect]. For [VerticalLineSegment]s, this
  /// will return true if [this] line segment fits within the x bounds of the
  /// [rect].
  bool crossAxisIntersects(Rect rect);

  /// Whether [this] line segment intersects [rect], bound by both its x and y
  /// constraints.
  bool intersects(Rect rect) {
    final intersectRect = Rect.fromPoints(start, end).intersect(rect);
    return intersectRect.width >= 0 && intersectRect.height >= 0;
  }

  LineSegment toZoomed({
    required double zoom,
    required double unzoomableOffsetLineStart,
    required double unzoomableOffsetLineEnd,
  });

  @visibleForTesting
  static double zoomedXPosition({
    required double x,
    required double zoom,
    required double unzoomableOffset,
  }) {
    assert(x >= unzoomableOffset);
    return (x - unzoomableOffset) * zoom + unzoomableOffset;
  }

  @override
  String toString() => '$start --> $end';
}

class HorizontalLineSegment extends LineSegment
    implements Comparable<HorizontalLineSegment> {
  HorizontalLineSegment(super.start, super.end, {super.opacity = 1.0})
      : assert(start.dy == end.dy);

  double get y => start.dy;

  @override
  bool crossAxisIntersects(Rect rect) => y >= rect.top && y <= rect.bottom;

  @override
  int compareTo(HorizontalLineSegment other) {
    // We first compare by cross axis so that the line segments are in
    // ascending order from top to bottom. If two line segments share a y value,
    // order them based on their starting x values.
    final compare = y.compareTo(other.y);
    if (compare == 0) {
      return start.dx.compareTo(other.start.dx);
    }
    return compare;
  }

  @override
  HorizontalLineSegment toZoomed({
    required double zoom,
    required double unzoomableOffsetLineStart,
    required double unzoomableOffsetLineEnd,
  }) {
    final zoomedLineStartX = LineSegment.zoomedXPosition(
      x: start.dx,
      zoom: zoom,
      unzoomableOffset: unzoomableOffsetLineStart,
    );
    final zoomedLineEndX = LineSegment.zoomedXPosition(
      x: end.dx,
      zoom: zoom,
      unzoomableOffset: unzoomableOffsetLineEnd,
    );
    return HorizontalLineSegment(
      Offset(zoomedLineStartX, start.dy),
      Offset(zoomedLineEndX, end.dy),
      opacity: opacity,
    );
  }
}

class VerticalLineSegment extends LineSegment
    implements Comparable<VerticalLineSegment> {
  VerticalLineSegment(
    super.start,
    super.end, {
    super.opacity = 1.0,
  }) : assert(start.dx == end.dx);

  double get x => start.dx;

  @override
  bool crossAxisIntersects(Rect rect) => x >= rect.left && x <= rect.right;

  @override
  int compareTo(VerticalLineSegment other) {
    // We first compare by cross axis so that the line segments are in
    // ascending order from left to right. If two line segments share an x
    // value, order them based on their starting y values.
    final compare = x.compareTo(other.x);
    if (compare == 0) {
      return start.dy.compareTo(other.start.dy);
    }
    return compare;
  }

  @override
  VerticalLineSegment toZoomed({
    required double zoom,
    required double unzoomableOffsetLineStart,
    required double unzoomableOffsetLineEnd,
  }) {
    final zoomedLineStartX = LineSegment.zoomedXPosition(
      x: start.dx,
      zoom: zoom,
      unzoomableOffset: unzoomableOffsetLineStart,
    );
    return VerticalLineSegment(
      Offset(zoomedLineStartX, start.dy),
      Offset(zoomedLineStartX, end.dy),
      opacity: opacity,
    );
  }
}
