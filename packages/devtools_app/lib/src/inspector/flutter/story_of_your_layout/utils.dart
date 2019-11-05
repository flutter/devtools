// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget for positioning sized widgets that follows layout as follows:
///      | top    |
/// left | center | right
///      | bottom |
@immutable
class BorderLayout extends StatelessWidget {
  const BorderLayout({
    Key key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    @required this.center,
  })  : assert(center != null),
        assert(left != null || top != null || right != null || bottom != null),
        super(key: key);

  final Widget center;
  final Widget top;
  final Widget left;
  final Widget right;
  final Widget bottom;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        if (top != null) top,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (left != null) left,
            center,
            if (right != null) right,
          ],
        ),
        if (bottom != null) bottom,
      ],
    );
  }
}
