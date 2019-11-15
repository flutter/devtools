// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_data_models.dart';

class ConstraintsDescription extends AnimatedWidget {
  const ConstraintsDescription({
    @required this.properties,
    AnimationController listenable,
    Key key,
  }) : super(key: key, listenable: listenable);

  final LayoutProperties properties;

  String describeAxis(double min, double max, String axis) {
    if (min == max) return '$axis=${min.toStringAsFixed(1)}';
    return '${min.toStringAsFixed(1)}<=$axis<=${max.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    if (properties?.constraints == null) {
      return const SizedBox();
    }
    final constraints = properties.constraints;
    if (constraints is BoxConstraints) {
      final textSpans = <TextSpan>[const TextSpan(text: 'BoxConstraints(')];
      if (!constraints.hasBoundedHeight && !constraints.hasBoundedWidth) {
        textSpans.add(
          TextSpan(
            text: 'unconstrained',
            style: inspector_text_styles.warning,
          ),
        );
      } else {
        textSpans.add(
          !constraints.hasBoundedWidth
              ? TextSpan(
                  text: 'width unconstrained',
                  style: inspector_text_styles.warning,
                )
              : TextSpan(
                  text: describeAxis(
                    constraints.minWidth,
                    constraints.maxWidth,
                    'w',
                  ),
                ),
        );
        textSpans.add(const TextSpan(text: ','));
        textSpans.add(
          !constraints.hasBoundedHeight
              ? TextSpan(
                  text: 'height unconstrained',
                  style: inspector_text_styles.warning,
                )
              : TextSpan(
                  text: describeAxis(
                    constraints.minHeight,
                    constraints.maxHeight,
                    'h',
                  ),
                ),
        );
      }
      textSpans.add(const TextSpan(text: ')'));
      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: RichText(
          text: TextSpan(
            style: inspector_text_styles.unimportantItalic,
            children: textSpans,
          ),
        ),
      );
      return FadeTransition(
        opacity: listenable,
        child: child,
      );
    } else {
      // TODO(albertusangga) Support SliverConstraint
      return const SizedBox();
    }
  }
}
