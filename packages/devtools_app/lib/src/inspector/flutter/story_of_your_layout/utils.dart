// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
